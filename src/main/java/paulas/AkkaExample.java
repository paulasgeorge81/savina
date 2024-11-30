package paulas;

import akka.actor.ActorRef;
import akka.actor.ActorSystem;
import akka.actor.Props;


public class AkkaExample {
    public static void main(String[] args) {
        ActorSystem system = ActorSystem.create("exampleSystem");
        ActorRef simpleActor = system.actorOf(Props.create(SimpleActor.class), "simpleActor");

        // Send a message to the actor
        simpleActor.tell("Hello, Actor!", ActorRef.noSender());

        // Keep the system alive for a few seconds to ensure the message is processed
        try {
            Thread.sleep(1000);  // Wait for 1 second
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        // Shutdown the system
        system.terminate();
    }
}

