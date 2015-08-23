
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

class GameOverScreenState extends State {
    static public var StateId :String = 'GameOverScreenState';

    var scene :Scene;
    var titleText :Text;
    var background :Visual;
    var start_clicked :Bool;
    var monster :Sprite;

    public function new() {
        super({ name: StateId });
        scene = new Scene('GameOverScreenScene');
    }

    override function init() {
        start_clicked = false;
    }

    override function onenter<T>(_value :T) {
        background = new Sprite({
            pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y),
            texture: Luxe.resources.texture('assets/title.png'),
            scene: scene
        });

        titleText = new Text({
            pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y * 0.3),
            text: 'Congratulations!',
            color: new Color(0, 0.2, 0.9, 0),
            align: TextAlign.center,
            align_vertical: TextAlign.center,
            scene: scene,
            parent: background
        });

        monster = new Sprite({
            pos: new Vector(250, Luxe.camera.size.y + 500),
            size: new Vector(400, 400),
            texture: Luxe.resources.texture('assets/monster.png'),
            scene: scene,
            parent: background,
            depth: 10
        });

        Actuate
            .tween(background.pos, 0.3, { y: Luxe.camera.size.y / 2 })
            .onComplete(function() {
                Actuate.tween(titleText.color, 0.3, { a: 1 });
            });

        Actuate.tween(monster.pos, 2, { y: Luxe.camera.size.y * 0.7 }).onComplete(outro);

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

    override function onleave<T>(_value :T) {
        Actuate
            .tween(background.pos, 0.3, { y: -Luxe.camera.size.y })
            .onComplete(function() {
                scene.empty();
            });
    }

    function outro() {
        Actuate.tween(monster.pos, 10, { y: monster.pos.y - 20, x: monster.pos.x + 30 });
        say(['Congratulations!', 'You\'ve completed Monster\'s Bal!', '... and with flying colors,\nI must say!'], 10).then(outro2);
    }

    function outro2() {
        Actuate.tween(monster.pos, 10, { y: monster.pos.y + 10, x: monster.pos.x + 30 });
        say(['Now you\'re ready to get\nback out under those beds\nand scare some children.'], 10).then(outro3);
    }

    function outro3() {
        Actuate.tween(monster.pos, 10, { y: monster.pos.y - 10, x: monster.pos.x - 10 });
        say(['Thanks for playing!'], 10);
    }

    function say(texts :Array<String>, duration :Int = 3) {
        var speechBubble = new entities.SpeechBubble({
            scene: Luxe.scene,
            depth: 10,
            texts: texts,
            duration: duration
        });
        monster.add(speechBubble);
        return speechBubble.get_promise();
    }
}
