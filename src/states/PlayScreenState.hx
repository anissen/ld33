
package states;

import luxe.Color;
import luxe.Scene;
import luxe.Sprite;
import luxe.States;
import luxe.Input;
import luxe.Text;
import luxe.tween.Actuate;
import luxe.Vector;

import luxe.Visual;
import phoenix.Texture.FilterType;

import luxe.importers.tiled.TiledMap;
import luxe.importers.tiled.TiledObjectGroup;

// ------------------

import luxe.physics.nape.DebugDraw;

import nape.phys.Body;
import nape.phys.BodyType;
import nape.geom.Vec2;
import nape.geom.Vec3;
import nape.phys.Material;
import nape.shape.Polygon;

import luxe.components.physics.nape.*;
import nape.callbacks.*;
import nape.constraint.PivotJoint;

using Lambda;

typedef PlayOptions = {
    mapId :Int,
    ball_count :Int,
    par :Int
}

class PlayScreenState extends State {
    static public var StateId :String = 'PlayScreenState';
    var scene :Scene;

    //The level tiles
    var mapId :Int;
    var map: TiledMap;
    var map_scale: Int = 1;

    //for attaching to the mouse when dragging
    var mouseJoint : PivotJoint;

    var ballCollisionType :CbType = new CbType();
    var obstacleCollisionType :CbType = new CbType();
    var bottomCollisionType :CbType = new CbType();

    var obstacles :Array<NapeBody>;
    var quest_obstacles :Array<NapeBody>;

    var ball_count :Int;
    var par :Int;
    var ballsLeft :Int;
    var ballsText :Text;
    var ball_col :CircleCollider;

    var ball_start_pos :Vector;

    var comboText :Text;
    var combos :Int;
    var maxCombos :Int;
    var trail_renderer :components.TrailRenderer;

    var monster :Sprite;

    var game_over :Bool;

    public function new() {
        super({ name: StateId });
        scene = new Scene('PlayScreenScene');
    }

    override function init() {
        
    }

    function setup_level() {
        game_over = false;
        Luxe.scene.empty();
        Luxe.physics.nape.space.clear();
        ballsLeft = ball_count;
        ball_col = null;
        combos = 0;
        maxCombos = 0;

        //Fetch the loaded tmx data from the assets
        var map_data = Luxe.resources.text('assets/level${mapId}.tmx').asset.text;

        //parse that data into a usable TiledMap instance
        map = new TiledMap({ format:'tmx', tiled_file_data: map_data });

        //Create the tilemap visuals
        // map.display({ scale:map_scale, filter:FilterType.nearest });

        reset_world();

        ballsText = new Text({
            pos: new Vector(0, 50),
            bounds: new luxe.Rectangle(0, 0, 256, 200),
            align: center,
            color: new Color(0.8, 0.4, 0.0)
        });

        comboText = new Text({
            pos: new Vector(0, 170),
            bounds: new luxe.Rectangle(0, 0, 256, 200),
            align: center,
            color: new Color(0.0, 0.6, 0.8)
        });

        updateBallsText();
        updateComboText();
    }

    function updateBallsText() {
        if (ballsLeft == 1) {
            ballsText.text = 'Last ball!';
            return;
        }
        ballsText.text = '$ballsLeft balls left';
    }

    function updateComboText() {
        comboText.text = 'Combo: ${combos}x\nMax: ${maxCombos}x';
    }

    function reset_world() {
        var w = map.total_width;
        var h = map.total_height;
        var x = Luxe.camera.size.x - w; //(Luxe.camera.size.x - w) / 2;
        var y = (Luxe.camera.size.y - h) / 2;

        ball_start_pos = new Vector(x + w / 2, y + 50);

        mouseJoint = new PivotJoint(Luxe.physics.nape.space.world, null, Vec2.weak(), Vec2.weak());
        mouseJoint.space = Luxe.physics.nape.space;
        mouseJoint.active = false;
        mouseJoint.stiff = false;

        var border = new Body(BodyType.STATIC);
        border.shapes.add(new Polygon(Polygon.rect(x, y, w, -1)));
        // border.shapes.add(new Polygon(Polygon.rect(y, h, w, 1)));
        border.shapes.add(new Polygon(Polygon.rect(x, y, -1, h)));
        border.shapes.add(new Polygon(Polygon.rect(x + w, y, 1, h)));
        border.space = Luxe.physics.nape.space;

        var bottom = new Body(BodyType.STATIC);
        bottom.shapes.add(new Polygon(Polygon.rect(x, y + h, w, 1)));
        bottom.space = Luxe.physics.nape.space;
        bottom.cbTypes.add(bottomCollisionType);

        new Sprite({
            centered: false,
            pos: new Vector(x, y),
            size: new Vector(w, h),
            color: new Color(0, 0.5, 0.8, 0.2)
        });

        obstacles = [];

        var count = 0;
        for (group in map.tiledmap_data.object_groups) {
            for (object in group.objects) {
                if (group.name == 'boxes') {

                    var w :Float = object.width;
                    var h :Float = object.height;
                    if (object.gid == 1) {
                        w *= 0.8;
                        h *= 0.8;
                    } else if (object.gid == 2) {
                        w *= 0.6;
                        h *= 0.6;
                    }

                    var rot = luxe.utils.Maths.radians(object.rotation);

                    var image_source = ['box.png', 'circle.png']; // horrible hack
                    var tex = image_source[object.gid-1];
                    var obstacle = new Sprite({
                        name: tex + Luxe.utils.uniqueid(),
                        pos: new Vector(x + 16 + object.pos.x, y - 16 + object.pos.y),
                        origin: new Vector(w / 2, h / 2),
                        size: new Vector(w, h),
                        scale: new Vector(0, 0),
                        rotation_z: rot,
                        texture: Luxe.resources.texture('assets/' + tex)
                    });
                    Actuate.tween(obstacle.scale, 0.4, { x: 1, y: 1 }).delay(count / 80);

                    var obstacle_col = new BoxCollider({
                        body_type: BodyType.STATIC,
                        material: Material.steel(),
                        x: x + 16 + object.pos.x,
                        y: y - 16 + object.pos.y,
                        w: w,
                        h: h,
                        rotation: rot
                    });
                    obstacle.add(obstacle_col);
                    obstacle_col.body.cbTypes.add(obstacleCollisionType);

                    obstacles.push(obstacle_col);

                    count++;
                }
            }
        }

        var quest_count = 10;
        quest_obstacles = obstacles.copy();
        while (quest_obstacles.length > quest_count) {
            var random_quest = quest_obstacles[Math.floor(quest_obstacles.length * Math.random())];
            quest_obstacles.remove(random_quest);
        }
        for (quest in quest_obstacles) {
            var visual :Visual;
            // TODO: Should be a component
            if (quest.entity.name.substring(0, 3) == 'box') {
                visual = new Sprite({
                    pos: new Vector(25.6, 12.8),
                    color: new Color(1, 0, 0, 0.8),
                    size: new Vector(58, 29),
                    scale: new Vector(0.95, 0.95),
                    parent: quest.entity,
                    depth: -1
                });
            } else {
                var radius = 15;
                visual = new Visual({
                    pos: new Vector(radius * 0.65, radius * 0.65),
                    color: new Color(1, 0, 0, 0.8),
                    geometry: Luxe.draw.circle({ r: radius }),
                    scale: new Vector(0.95, 0.95),
                    parent: quest.entity,
                    depth: -1
                });
            }

            Actuate.tween(visual.scale, 1.5, { x: 1.05, y: 1.05 })
                .reflect()
                .repeat();
            
            // var questSprite :Sprite = cast quest.entity;
            // questSprite.color.r = 1;
            // questSprite.rotation_z -= 5;
            // Actuate.tween(questSprite, 0.5, { rotation_z: questSprite.rotation_z + 10 })
            //     .reflect()
            //     .repeat();
        }

        var bouncer = new Sprite({
            pos: new Vector(x + w / 2, y + h - 25),
            texture: Luxe.resources.texture('assets/bouncer.png')
        });

        var bouncer_col = new BoxCollider({
            body_type: BodyType.STATIC,
            material: Material.steel(),
            x: bouncer.pos.x,
            y: bouncer.pos.y,
            w: bouncer.size.x,
            h: bouncer.size.y
        });
        bouncer.add(bouncer_col);

        // Actuate.tween(bouncer.pos, 3, { x: x + 16 + w })
        //         .reflect()
        //         .repeat();

        var obstacleInteractionListener = new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, ballCollisionType, obstacleCollisionType, hitObstacle);
        Luxe.physics.nape.space.listeners.add(obstacleInteractionListener);

        var bottominteractionListener = new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, ballCollisionType, bottomCollisionType, hitBottom);
        Luxe.physics.nape.space.listeners.add(bottominteractionListener);

        monster = new Sprite({
            pos: new Vector(65, Luxe.camera.size.y - 65),
            size: new Vector(320, 320),
            texture: Luxe.resources.texture('assets/monster.png')
        });

        new Sprite({
            pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y / 2),
            texture: Luxe.resources.texture('assets/sidebar_ui.png')
        });

        Luxe.timer.schedule(1, function() {
            if (monster == null) return;
            var rnd = Math.random();
            if (rnd < 0.5) {
                monster.texture = Luxe.resources.texture('assets/monster.png');
            } else if (rnd < 0.9) {
                monster.texture = Luxe.resources.texture('assets/monster_closed_mouth.png');
            } else {
                monster.texture = Luxe.resources.texture('assets/monster_closed_eyes.png');
            }
        }, true);
    }

    function hitObstacle(collision :InteractionCallback) :Void {
        if (ball_col == null || game_over) return;

        var ballBody :nape.phys.Body = collision.int1.castBody;
        var obstacleBody :nape.phys.Body = collision.int2.castBody;

        var obstacle = obstacles.find(function(ob) {
            return ob.body == obstacleBody;
        });
        obstacles.remove(obstacle);
        quest_obstacles.remove(obstacle);

        ballBody.torque = -1 + 2 * Math.random();

        var position = new Vector((ballBody.position.x + obstacleBody.position.x) / 2, (ballBody.position.y + obstacleBody.position.y) / 2);

        if (obstacles.empty()) {
            won();
        } else if (quest_obstacles.empty()) {
            won();
        }
        
        var hitVisual = new Sprite({
            pos: position,
            texture: Luxe.resources.texture('assets/cloud.png'),
            size: new Vector(25, 25),
            scale: new Vector(0.5, 0.5),
            rotation_z: 360 * Math.random(),
            depth: 10
        });
        Actuate.tween(hitVisual.scale, 0.3, { x: 1, y: 1 }).onComplete(function() {
            hitVisual.destroy();
        });

        obstacleBody.space = null;
        obstacle.entity.destroy();

        var sounds = ["A0", "A1", "A2", "A3", "A4", "A5", "A6", "A7", "Ab1", "Ab2", "Ab3", "Ab4", "Ab5", "Ab6", "Ab7", "B0", "B1", "B2", "B3", "B4", "B5", "B6", "B7", "Bb0", "Bb1", "Bb2", "Bb3", "Bb4", "Bb5", "Bb6", "Bb7", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "Db1", "Db2", "Db3", "Db4", "Db5", "Db6", "Db7", "E1", "E2", "E3", "E4", "E5", "E6", "E7", "Eb1", "Eb2", "Eb3", "Eb4", "Eb5", "Eb6", "Eb7", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "G1", "G2", "G3", "G4", "G5", "G6", "G7", "Gb1", "Gb2", "Gb3", "Gb4", "Gb5", "Gb6", "Gb7"];
        var sound = sounds[Math.floor(sounds.length * Math.random())];
        Luxe.audio.play(sound); // TODO: Change to .ogg
        // Luxe.audio.pan(sound, Math.random());

        Luxe.camera.shake(2);

        if (trail_renderer != null) {
            trail_renderer.startSize = luxe.utils.Maths.clamp(trail_renderer.startSize + 2, 1, 6);
            trail_renderer.maxLength = luxe.utils.Maths.clamp(trail_renderer.maxLength + 30, 150, 300);
            trail_renderer.trailColor.h = luxe.utils.Maths.clamp(trail_renderer.trailColor.h + 20, 200, 360);
        }

        combos++;
        if (combos > maxCombos) maxCombos = combos;
        if (combos == 10 || combos == 15 || combos == 20) {
            if (!quest_obstacles.empty()) {
                entities.Notification.Toast({
                    text: '${combos}x Combo!\nExtra Ball!',
                    scene: Luxe.scene,
                    pos: new Vector(comboText.pos.x + comboText.geom.text_width, comboText.pos.y),
                    color: new Color(0, 0, 1)
                });
                say([['C-c-combo!'], ['Nice one'], ['Well done!'], ['Awesome'], ['Bam!'], ['Yay, an extra ball!'], ['Now you\'re working your magic!']], 2, 0.5);
            }
            ballsLeft++;
            updateBallsText();
        }
        updateComboText();
    }

    function won() {
        game_over = true;
        entities.Notification.Toast({
            text: 'Level Won!',
            scene: Luxe.scene,
            pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y / 2),
            color: new Color(0, 1, 0)
        });
        
        say([['Good job!'], ['Impressive'], ['I knew you could do it'], ['Piece of cake'], ['Like scaring small children'], ['Like stealing candy\nfrom a child']], 2, 0.7).then(function() {
            if (mapId == 7) {
                Main.switch_to_state(GameOverScreenState.StateId);
                return;
            }
            Main.switch_to_state(PlayScreenState.StateId, { mapId: mapId + 1, ball_count: 5, par: 5 });
        });
    }

    function hitBottom(collision :InteractionCallback) :Void {
        ball_lost();
    }

    function ball_lost() {
        ball_col.body.space = null;
        ball_col.entity.destroy();
        ball_col = null;

        if (ballsLeft == 0) {
            entities.Notification.Toast({
                text: 'Level Lost!',
                scene: Luxe.scene,
                pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y / 2),
                color: new Color(1, 0, 0)
            });
            say([['Too bad'], ['Better luck next time'], ['Don\'t worry,\nit was a hard one', '... for a n00b!'], ['Give it another try'], ['Yeah, it\'s a hard one']], 3, 0.7).then(setup_level);
        } else {
            if (combos == 0) {
                say([['Did I not explain the\ngoal of this game?'], ['That was very bad.'], ['Maybe this game is not for you.'], ['Pff!', 'Sorry, but that was hilarious'], ['That was bad and\nyou should feel bad.'], ['First rule of\nMonster\'s Ball:', 'Hit the obstacles'], ['Pratice makes perfect.', 'A LOT of pratice.']], 3, 0.8);
            }
        }
    }

    function createBall(pos :Vector) {
        if (ballsLeft <= 0 || game_over) return;

        var ball_size = 16;
        var ball = new Sprite({
            name: 'ball',
            pos: ball_start_pos.clone(),
            size: new Vector(16, 16),
            texture: Luxe.resources.texture('assets/ball.png')
        });
        var rubber = Material.rubber();
        rubber.elasticity = 2;
        ball_col = new CircleCollider({
            body_type:BodyType.DYNAMIC,
            material: rubber,
            x: ball.pos.x,
            y: ball.pos.y,
            r: ball_size / 2
        });
        ball.add(ball_col);
        ball_col.body.cbTypes.add(ballCollisionType);

        var diff = Vector.Subtract(pos, ball_start_pos);
        var vel = diff.normalized.multiplyScalar(500);
        ball_col.body.velocity = Vec2.get(vel.x, vel.y);
        ball_col.body.angularVel = -200 + 400 * Math.random();

        ballsLeft--;
        updateBallsText();

        combos = 0;
        updateComboText();

        trail_renderer = new components.TrailRenderer();
        ball.add(trail_renderer);

        var particles = create_particle_system();
        particles.parent = ball;
        particles.pos = ball.pos;

        Luxe.camera.shake(2);
    }

    override function onenter<T>(_value :T) {
        var options :PlayOptions = cast _value;
        mapId = options.mapId;
        ball_count = options.ball_count;
        par = options.par;
        setup_level();

        say([['Good luck'], ['Have fun'], ['Enjoy!'], ['You\'ll do great!']], 2, 0.7);
    }

    override function onleave<T>(_value :T) {
        Luxe.scene.empty();
    }

    function say(texts :Array<Array<String>>, duration :Int = 3, probability :Float = 1) {
        if (Math.random() > probability) {
            return new snow.api.Promise(function(resolve, reject) {
                resolve();
            });
        }

        var speechBubble = new entities.SpeechBubble({
            scene: Luxe.scene,
            depth: 10,
            texts: texts[Math.floor(texts.length * Math.random())],
            duration: duration
        });
        monster.add(speechBubble);
        return speechBubble.get_promise();
    }

    override function update(dt :Float) {
        if (ball_col == null) {
            var start = ball_start_pos;
            var mouse_pos = Luxe.camera.screen_point_to_world(Luxe.screen.cursor.pos.clone());
            var diff = Vector.Subtract(mouse_pos, start);
            var end = Vector.Add(start, Vector.Multiply(diff.normalized, 100));
            Luxe.draw.line({
                p0: start,
                p1: end,
                immediate: true
            });
        } else {
            if (trail_renderer != null) {
                if (trail_renderer.startSize > 1) trail_renderer.startSize -= dt * 2;
                if (trail_renderer.maxLength > 150) trail_renderer.maxLength -= dt * 20;
                if (trail_renderer.trailColor.h > 200) trail_renderer.trailColor.h -= dt * 20;
            }
        }
    }

    override function onmousedown( e:MouseEvent ) {
        var mousePoint = Vec2.get(e.pos.x, e.pos.y);

        if (ball_col != null) {
            ball_lost();
        }
        createBall(Luxe.camera.screen_point_to_world(e.pos));
    }

    override function onkeyup(e :KeyEvent) {
        switch (e.keycode) {
            case Key.key_r: setup_level();
            case Key.escape: Main.switch_to_state(TitleScreenState.StateId);
        }
    }

    function create_particle_system() {
        var content = '{
            "emit_time": 0.05,
            "emit_count": 1,
            "direction": 0,
            "direction_random": 360,
            "speed": 1.6517857142857142,
            "speed_random": 0.8482142857142858,
            "end_speed": 0,
            "life": 1.8973214285714284,
            "life_random": 0,
            "rotation": 0,
            "rotation_random": 33.75,
            "end_rotation": 0,
            "end_rotation_random": 81.96428571428571,
            "rotation_offset": 0,
            "pos_offset": {
                "_construct": false,
                "ignore_listeners": false,
                "w": 0,
                "z": 0,
                "y": 0,
                "x": 0
            },
            "pos_random": {
                "_construct": false,
                "ignore_listeners": false,
                "w": 0,
                "z": 0,
                "y": 12.053571428571429,
                "x": 12.053571428571429
            },
            "gravity": {
                "_construct": false,
                "ignore_listeners": false,
                "w": 0,
                "z": 0,
                "y": 0.8928571428571388,
                "x": 0
            },
            "start_size": {
                "_construct": false,
                "ignore_listeners": false,
                "w": 0,
                "z": 0,
                "y": 64,
                "x": 64
            },
            "start_size_random": {
                "_construct": false,
                "ignore_listeners": false,
                "w": 0,
                "z": 0,
                "y": 3.7142857142857144,
                "x": 3.142857142857143
            },
            "end_size": {
                "_construct": false,
                "ignore_listeners": false,
                "w": 0,
                "z": 0,
                "y": 8,
                "x": 8
            },
            "end_size_random": {
                "_construct": false,
                "ignore_listeners": false,
                "w": 0,
                "z": 0,
                "y": 0,
                "x": 0
            },
            "start_color": {
                "v": 0.5,
                "s": 1,
                "h": 60,
                "refreshing": false,
                "is_hsv": true,
                "is_hsl": false,
                "a": 1,
                "b": 0,
                "g": 0.5,
                "r": 0.5
            },
            "end_color": {
                "v": 0.5,
                "s": 1,
                "h": 53.035714285714285,
                "refreshing": false,
                "is_hsv": true,
                "is_hsl": false,
                "a": 0,
                "b": 0,
                "g": 0.4419642857142857,
                "r": 0.5
            }
        }';

        var content2 = Luxe.resources.text('assets/fireflies.json').asset.text;

        var json = haxe.Json.parse(content2);

        // grab loaded particle values
        var loaded :luxe.options.ParticleOptions.ParticleEmitterOptions = {
            emit_time: json.emit_time,
            emit_count: json.emit_count,
            direction: json.direction,
            direction_random: json.direction_random,
            speed: json.speed,
            speed_random: json.speed_random,
            end_speed: json.end_speed,
            life: json.life,
            life_random: json.life_random,
            rotation: json.zrotation,
            rotation_random: json.rotation_random,
            end_rotation: json.end_rotation,
            end_rotation_random: json.end_rotation_random,
            rotation_offset: json.rotation_offset,
            pos_offset: new Vector(json.pos_offset.x, json.pos_offset.y),
            pos_random: new Vector(json.pos_random.x, json.pos_random.y),
            gravity: new Vector(json.gravity.x, json.gravity.y),
            start_size: new Vector(json.start_size.x, json.start_size.y),
            start_size_random: new Vector(json.start_size_random.x, json.start_size_random.y),
            end_size: new Vector(json.end_size.x, json.end_size.y),
            end_size_random: new Vector(json.end_size_random.x, json.end_size_random.y),
            start_color: new Color(json.start_color.r, json.start_color.g, json.start_color.b, json.start_color.a),
            end_color: new Color(json.end_color.r, json.end_color.g, json.end_color.b, json.end_color.a)
        };
        loaded.particle_image = Luxe.resources.texture('assets/particle.png');

        var particles = new luxe.Particles.ParticleSystem({name: 'particles'});
        // particles.pos = Luxe.screen.mid.clone();
        particles.add_emitter(loaded);
        return particles;
    }
}
