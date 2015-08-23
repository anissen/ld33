
package states;

import luxe.Color;
import luxe.Input.KeyEvent;
import luxe.Input.Key;
import luxe.Input;
import luxe.Scene;
import luxe.Sprite;
import luxe.States;
import luxe.Text;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Visual;

class TitleScreenState extends State {
    static public var StateId :String = 'TitleScreenState';

    var scene :Scene;
    var titleText :Text;
    var background :Visual;

    public function new() {
        super({ name: StateId });
        scene = new Scene('TitleScreenScene');
    }

    override function init() {

    }

    override function onenter<T>(_value :T) {
        background = new Sprite({
            pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y),
            texture: Luxe.resources.texture('assets/title.png'),
            scene: scene
        });

        titleText = new Text({
            pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y * 0.7),
            text: 'Click to start',
            color: new Color(0, 0, 1, 0),
            align: TextAlign.center,
            align_vertical: TextAlign.center,
            scene: scene,
            parent: background
        });

        Actuate
            .tween(titleText.pos, 0.8, { y: Luxe.camera.size.y * 0.8 })
            .reflect()
            .repeat();

        Actuate
            .tween(background.pos, 0.3, { y: Luxe.camera.size.y / 2 })
            .onComplete(function() {
                Actuate.tween(titleText.color, 0.3, { a: 1 });
            });
    }

    override function onleave<T>(_value :T) {
        Actuate
            .tween(background.pos, 0.3, { y: -Luxe.camera.size.y })
            .onComplete(function() {
                scene.empty();
            });
    }

    override function onmousedown(e :MouseEvent) {
        Main.switch_to_state(PlayScreenState.StateId, { mapId: 1, ball_count: 5, par: 5 });
    }
}
