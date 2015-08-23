
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
    map :String,
    ball_count :Int,
    par :Int
}

class PlayScreenState extends State {
    static public var StateId :String = 'PlayScreenState';
    var scene :Scene;

    //The level tiles
    var map_asset :String;
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

    var trail_renderer :components.TrailRenderer;

    public function new() {
        super({ name: StateId });
        scene = new Scene('PlayScreenScene');
    }

    override function init() {
        Luxe.events.listen('won', function(_) {
            ballsText.text = 'YOU WON!';
        });

        Luxe.events.listen('hit', function(_) {
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
        });
    }

    function setup_level() {
        Luxe.scene.empty();
        Luxe.physics.nape.space.clear();
        ballsLeft = ball_count;
        ball_col = null;

        //Fetch the loaded tmx data from the assets
        var map_data = Luxe.resources.text(map_asset).asset.text;

        //parse that data into a usable TiledMap instance
        map = new TiledMap({ format:'tmx', tiled_file_data: map_data });

        //Create the tilemap visuals
        // map.display({ scale:map_scale, filter:FilterType.nearest });

        reset_world();

        ballsText = new Text({
            pos: new Vector(0, 0),
            bounds: new luxe.Rectangle(0, 0, 200, 200),
            align: center
        });
        updateBallsText();
    }

    function updateBallsText() {
        if (ballsLeft == 1) {
            ballsText.text = 'Last ball!';
            return;
        }
        ballsText.text = '$ballsLeft balls left';
    }

    function reset_world() {
        var w = map.total_width;
        var h = map.total_height;
        var x = Luxe.camera.size.x - w; //(Luxe.camera.size.x - w) / 2;
        var y = (Luxe.camera.size.y - h) / 2;

        ball_start_pos = new Vector(x + w / 2, y + 20);

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
                    var obstacle = new Sprite({
                        pos: new Vector(x + 16 + object.pos.x, y - 16 + object.pos.y),
                        size: new Vector(w, h),
                        scale: new Vector(0, 0),
                        rotation_z: rot,
                        texture: Luxe.resources.texture('assets/' + image_source[object.gid-1])
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
            // TODO: Should be a component
            var radius = 15;
            new Visual({
                pos: new Vector(radius * 0.6, radius * 0.6),
                color: new Color(1, 0, 0, 0.8),
                geometry: Luxe.draw.circle({ r: radius }),
                parent: quest.entity,
                depth: -1
            });
        }

        var obstacleInteractionListener = new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, ballCollisionType, obstacleCollisionType, hitObstacle);
        Luxe.physics.nape.space.listeners.add(obstacleInteractionListener);

        var bottominteractionListener = new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, ballCollisionType, bottomCollisionType, hitBottom);
        Luxe.physics.nape.space.listeners.add(bottominteractionListener);

        new Sprite({
            pos: new Vector(65, Luxe.camera.size.y - 65),
            size: new Vector(320, 320),
            texture: Luxe.resources.texture('assets/monster.png')
        });

        new Sprite({
            pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y / 2),
            texture: Luxe.resources.texture('assets/sidebar_ui.png')
        });
    }

    function hitObstacle(collision :InteractionCallback) :Void {
        var ballBody :nape.phys.Body = collision.int1.castBody;
        var obstacleBody :nape.phys.Body = collision.int2.castBody;

        var obstacle = obstacles.find(function(ob) {
            return ob.body == obstacleBody;
        });
        obstacles.remove(obstacle);
        quest_obstacles.remove(obstacle);

        var position = new Vector((ballBody.position.x + obstacleBody.position.x) / 2, (ballBody.position.y + obstacleBody.position.y) / 2);

        Luxe.events.fire('hit', { entity: obstacle.entity, body: obstacle.body, position: position });
        if (obstacles.empty()) Luxe.events.fire('won');
        if (quest_obstacles.empty()) Luxe.events.fire('won');
        
        var hitVisual = new Visual({
            pos: position,
            color: new Color(1, 1, 1, 0.4),
            geometry: Luxe.draw.circle({ r: 25 }),
            scale: new Vector(0.5, 0.5),
            depth: 10
        });
        Actuate.tween(hitVisual.scale, 0.3, { x: 1, y: 1 }).onComplete(function() {
            hitVisual.destroy();
        });

        obstacleBody.space = null;
        obstacle.entity.destroy();
    }

    function hitBottom(collision :InteractionCallback) :Void {
        ball_col.body.space = null;
        ball_col.entity.destroy();
        ball_col = null;
    }

    function createBall(pos :Vector) {
        if (ballsLeft <= 0) return;

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
        var vel = diff.normalized.multiplyScalar(300);
        ball_col.body.velocity = Vec2.get(vel.x, vel.y);
        ball_col.body.angularVel = -200 + 400 * Math.random();

        ballsLeft--;
        updateBallsText();

        trail_renderer = new components.TrailRenderer();
        ball.add(trail_renderer);

        Luxe.camera.shake(2);
    }

    override function onenter<T>(_value :T) {
        var options :PlayOptions = cast _value;
        map_asset = options.map;
        ball_count = options.ball_count;
        par = options.par;
        setup_level();
    }

    override function onleave<T>(_value :T) {

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

    override function onkeyup(e :KeyEvent) {
        switch (e.keycode) {
            case Key.key_r: setup_level();
    override function onmousedown( e:MouseEvent ) {
        var mousePoint = Vec2.get(e.pos.x, e.pos.y);

        if (ball_col == null) {
            createBall(Luxe.camera.screen_point_to_world(e.pos));
        }

        }
    }
}
