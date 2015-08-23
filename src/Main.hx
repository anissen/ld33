
import luxe.States;
import luxe.Input;
import luxe.tween.Actuate;
import states.*;
import luxe.Vector;

class Main extends luxe.Game {
    static public var states :States;

    override function config(config:luxe.AppConfig) {
        config.render.antialiasing = 4;

        config.preload.textures.push({ id:'assets/square.png' });
        config.preload.textures.push({ id:'assets/circle.png' });
        config.preload.textures.push({ id:'assets/ball.png' });
        config.preload.textures.push({ id:'assets/box.png' });
        config.preload.textures.push({ id:'assets/monster.png' });
        config.preload.textures.push({ id:'assets/sidebar_ui.png' });
        config.preload.textures.push({ id:'assets/title.png' });
        config.preload.textures.push({ id:'assets/particle.png' });

        config.preload.texts.push({ id:'assets/fireflies.json' });
        config.preload.texts.push({ id:'assets/test.tmx' });
        config.preload.texts.push({ id:'assets/test2.tmx' });
        config.preload.texts.push({ id:'assets/level3.tmx' });
        config.preload.texts.push({ id:'assets/level4.tmx' });

        var sounds = ["A0", "A1", "A2", "A3", "A4", "A5", "A6", "A7", "Ab1", "Ab2", "Ab3", "Ab4", "Ab5", "Ab6", "Ab7", "B0", "B1", "B2", "B3", "B4", "B5", "B6", "B7", "Bb0", "Bb1", "Bb2", "Bb3", "Bb4", "Bb5", "Bb6", "Bb7", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "Db1", "Db2", "Db3", "Db4", "Db5", "Db6", "Db7", "E1", "E2", "E3", "E4", "E5", "E6", "E7", "Eb1", "Eb2", "Eb3", "Eb4", "Eb5", "Eb6", "Eb7", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "G1", "G2", "G3", "G4", "G5", "G6", "G7", "Gb1", "Gb2", "Gb3", "Gb4", "Gb5", "Gb6", "Gb7"];
        for (sound in sounds) {
            config.preload.sounds.push({ 
                id: 'assets/sounds/hit/$sound.mp3', 
                name: sound, 
                is_stream: false
            }); 
        }
        return config;
    }

    override function ready() {
        //Set the sky/background color
        Luxe.renderer.clear_color.rgb(0x001f3f);

        //Tell the camera to keep the world size fixed,
        //And automatically fit the window size
        Luxe.camera.size = new Vector(768, 512);
        Actuate.defaultEase = luxe.tween.easing.Quad.easeInOut;

        states = new States({ name: 'state_machine' });
        states.add(new TitleScreenState());
        states.add(new PlayScreenState());

        switch_to_state(TitleScreenState.StateId);
    }

    static public function switch_to_state<T>(state :String, ?args :T) {
        states.set(state, args);
    }

    override function onkeyup(e :KeyEvent) {
        switch (e.keycode) {
            case Key.key_1: switch_to_state(PlayScreenState.StateId, { map: 'assets/test2.tmx', ball_count: 10, par: 5 });
            case Key.key_2: switch_to_state(PlayScreenState.StateId, { map: 'assets/level3.tmx', ball_count: 10, par: 5 });
            case Key.key_3: switch_to_state(PlayScreenState.StateId, { map: 'assets/level4.tmx', ball_count: 10, par: 5 });
        }
    }
}
