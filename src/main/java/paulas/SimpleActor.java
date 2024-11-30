package paulas;

import akka.actor.UntypedActor;
import akka.actor.Props;

public class SimpleActor extends UntypedActor {

    @Override
    public void onReceive(Object message) throws Exception {
        if (message instanceof String) {
            System.out.println("Received message: " + message);
        } else {
            unhandled(message);
        }
    }

    public static Props props() {
        return Props.create(SimpleActor.class);
    }
}