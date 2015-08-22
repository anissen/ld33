
import luxe.States;
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
        config.preload.texts.push({ id:'assets/test.tmx' });
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
        states.add(new MenuScreenState());
        states.add(new PlayScreenState());

        switch_to_state(PlayScreenState.StateId);
    }

    static public function switch_to_state<T>(state :String, ?args :T) {
        states.set(state, args);
    }
}
