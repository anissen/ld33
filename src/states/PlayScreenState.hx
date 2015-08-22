
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
import nape.phys.Material;
import nape.shape.Polygon;

import luxe.components.physics.nape.*;
import nape.callbacks.*;
import nape.constraint.PivotJoint;

using Lambda;

class PlayScreenState extends State {
    static public var StateId :String = 'PlayScreenState';
    var scene :Scene;

    //The level tiles
    var map: TiledMap;
    var map_scale: Int = 1;

    var drawer : DebugDraw;

    //for attaching to the mouse when dragging
    var mouseJoint : PivotJoint;

    var ballCollisionType :CbType = new CbType();
    var obstacleCollisionType :CbType = new CbType();
    var bottomCollisionType :CbType = new CbType();

    var obstacles :Array<NapeBody>;

    var ballsLeft :Int = 10;
    var ballsText :Text;
    var ball_col :CircleCollider;

    var ball_start_pos :Vector;

    public function new() {
        super({ name: StateId });
        scene = new Scene('PlayScreenScene');
    }

    override function init() {
        //Fetch the loaded tmx data from the assets
        var map_data = Luxe.resources.text('assets/test.tmx').asset.text;

        //parse that data into a usable TiledMap instance
        map = new TiledMap({ format:'tmx', tiled_file_data: map_data });

        //Create the tilemap visuals
        // map.display({ scale:map_scale, filter:FilterType.nearest });

        ballsText = new Text({
            pos: new Vector(Luxe.screen.mid.x, 100),
            align: center
        });
        updateBallsText();

        Luxe.events.listen('won', function(_) {
            ballsText.text = 'YOU WON!';
        });

        reset_world();
    }

    function updateBallsText() {
        ballsText.text = '$ballsLeft balls left';
    }

    function reset_world() {
        if (drawer != null) {
            drawer.destroy();
            drawer = null;
        }

        //create the drawer, and assign it to the nape debug drawer
        drawer = new DebugDraw();
        Luxe.physics.nape.debugdraw = drawer;

        var w = map.total_width;
        var h = map.total_height;
        var x = (Luxe.screen.width - w) / 2;
        var y = (Luxe.screen.height - h) / 2;

        ball_start_pos = new Vector(Luxe.screen.mid.x, y + 20);

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
        drawer.add(border);

        var bottom = new Body(BodyType.STATIC);
        bottom.shapes.add(new Polygon(Polygon.rect(x, y + h, w, 1)));
        bottom.space = Luxe.physics.nape.space;
        bottom.cbTypes.add(bottomCollisionType);
        drawer.add(bottom);

        new Sprite({
            pos: Luxe.screen.mid.clone(),
            size: new Vector(w, h),
            color: new Color(0, 0.5, 0.8, 0.2)
        });

        obstacles = [];

        for (group in map.tiledmap_data.object_groups) {
            for (object in group.objects) {
                if (group.name == 'boxes') {

                    var w :Float = object.width;
                    var h :Float = object.height;
                    if (object.gid == 1) {
                        w *= 0.75;
                        h *= 0.75;
                    } else if (object.gid == 2) {
                        w /= 2;
                        h /= 2;
                    }

                    var rot = luxe.utils.Maths.radians(object.rotation);

                    var image_source = ['box.png', 'circle.png']; // horrible hack
                    var obstacle = new Sprite({
                        pos: new Vector(x + 32 + object.pos.x, y - 32 + object.pos.y),
                        size: new Vector(w, h),
                        rotation_z: rot,
                        texture: Luxe.resources.texture('assets/' + image_source[object.gid-1])
                    });

                    trace('Rotation: ${rot}');

                    var obstacle_col = new BoxCollider({
                        body_type: BodyType.STATIC,
                        material: Material.steel(),
                        x: x + 32 + object.pos.x,
                        y: y - 32 + object.pos.y,
                        w: w,
                        h: h,
                        rotation: rot
                    });
                    obstacle.add(obstacle_col);
                    obstacle_col.body.cbTypes.add(obstacleCollisionType);

                    obstacles.push(obstacle_col);
                }
            }
        }

        var obstacleInteractionListener = new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, ballCollisionType, obstacleCollisionType, hitObstacle);
        Luxe.physics.nape.space.listeners.add(obstacleInteractionListener);

        var bottominteractionListener = new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, ballCollisionType, bottomCollisionType, hitBottom);
        Luxe.physics.nape.space.listeners.add(bottominteractionListener);
    }

    function hitObstacle(collision :InteractionCallback) :Void {
        // collision.
        // trace('ballToWall');
        var ballBody :nape.phys.Body = collision.int1.castBody;
        var obstacleBody :nape.phys.Body = collision.int2.castBody;

        var obstacle = obstacles.find(function(ob) {
            return ob.body == obstacleBody;
        });
        obstacles.remove(obstacle);

        var position = new Vector((ballBody.position.x + obstacleBody.position.x) / 2, (ballBody.position.y + obstacleBody.position.y) / 2);

        Luxe.events.fire('hit', { entity: obstacle.entity, body: obstacle.body, position: position });
        if (obstacles.empty()) Luxe.events.fire('won');
        
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

        drawer.remove(obstacleBody);
        obstacleBody.space = null;
        obstacle.entity.destroy();
    }

    function hitBottom(collision :InteractionCallback) :Void {
        drawer.remove(ball_col.body);
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
        var vel = diff.normalized.multiplyScalar(700);
        ball_col.body.velocity = Vec2.get(vel.x, vel.y);

        ballsLeft--;
        updateBallsText();
    }

    override function onenter<T>(_value :T) {
        trace('ENTER $StateId');
    }

    override function onleave<T>(_value :T) {
        trace('LEAVE $StateId');
    }

    override function update(dt :Float) {
        if (ball_col == null) {
            var start = ball_start_pos;
            var mouse_pos = Luxe.screen.cursor.pos.clone();
            var diff = Vector.Subtract(mouse_pos, start);
            var end = Vector.Add(start, Vector.Multiply(diff.normalized, 100));
            Luxe.draw.line({
                p0: start,
                p1: end,
                immediate: true
            });
        }
    }

    override function onkeyup(e :KeyEvent) {
        switch (e.keycode) {
            case Key.key_r:
                Luxe.scene.empty();
                Luxe.physics.nape.space.clear();
                reset_world();
            case Key.key_g: Luxe.physics.nape.draw = !Luxe.physics.nape.draw;
        }
    }

    override function onmouseup( e:MouseEvent ) {
        mouseJoint.active = false;
    }

    override function onmousedown( e:MouseEvent ) {
        var mousePoint = Vec2.get(e.pos.x, e.pos.y);

        if (ball_col == null) {
            createBall(e.pos);
        }

        for (body in Luxe.physics.nape.space.bodiesUnderPoint(mousePoint)) {
            if (!body.isDynamic()) {
                continue;
            }

            mouseJoint.anchor1.setxy(e.pos.x, e.pos.y);

            // Configure hand joint to drag this body.
            //   We initialise the anchor point on this body so that
            //   constraint is satisfied.
            //
            //   The second argument of worldPointToLocal means we get back
            //   a 'weak' Vec2 which will be automatically sent back to object
            //   pool when setting the mouseJoint's anchor2 property.
            mouseJoint.body2 = body;
            mouseJoint.anchor2.set( body.worldPointToLocal(mousePoint, true));

            // Enable hand joint!
            mouseJoint.active = true;
            break;
        }

        mousePoint.dispose();
    } //onmousedown

    override function onmousemove( e:MouseEvent ) {
        if (mouseJoint.active) {
            mouseJoint.anchor1.setxy(e.pos.x, e.pos.y);
        }
    }

    #if mobile
        override function ontouchmove( e:TouchEvent ) {
            if (mouseJoint.active) {
                mouseJoint.anchor1.setxy(e.pos.x, e.pos.y);
            }
        } //ontouchmove
    #end //mobile
}
