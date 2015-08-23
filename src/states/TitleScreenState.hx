
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
    var start_clicked :Bool;
    var monster :Sprite;

    public function new() {
        super({ name: StateId });
        scene = new Scene('TitleScreenScene');
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
            pos: new Vector(Luxe.camera.size.x / 2, Luxe.camera.size.y * 0.7),
            text: 'Click to start',
            color: new Color(0, 0, 0.7, 0),
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
        if (start_clicked) {
            start();
            return;
        }

        titleText.visible = false;
        monster.visible = true;
        Actuate.tween(monster.pos, 2, { y: Luxe.camera.size.y * 0.7 }).onComplete(intro);
    }

    function intro() {
        Actuate.tween(monster.pos, 10, { y: monster.pos.y - 20, x: monster.pos.x + 30 });
        say(['Hello!', 'Welcome to Monster\'s Ball!', 'I\'ll be your guide\nduring your stay.'], 10).then(intro2);
    }

    function intro2() {
        Actuate.tween(monster.pos, 10, { y: monster.pos.y + 10, x: monster.pos.x + 30 });
        say(['Monster\'s Ball is every\nmonster\'s favorite pasttime!', 'We come here to unwind after\na long day of scaring people.'], 10).then(intro3);
    }

    function intro3() {
        Actuate.tween(monster.pos, 10, { y: monster.pos.y - 10, x: monster.pos.x - 10 });
        say(['So, what is Monster\'s Ball, you ask?', 'Well, it\'s simple, really.', 'You throw rubber balls and\ntry to hit all the obstacles.'], 10).then(intro4);
    }

    function intro4() {
        Actuate.tween(monster.pos, 10, { y: monster.pos.y + 60, x: monster.pos.x - 90 });
        say(['Easy, right?\nShould we get started?', 'I\'ll be right over\nhere to help you.', 'Here we go!'], 10).then(start);
    }

    function start() {
        Main.switch_to_state(PlayScreenState.StateId, { mapId: 1, ball_count: 5, par: 5 });
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
