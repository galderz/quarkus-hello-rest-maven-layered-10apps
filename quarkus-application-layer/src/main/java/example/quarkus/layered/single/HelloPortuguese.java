package example.quarkus.layered.single;

import io.quarkus.arc.properties.IfBuildProperty;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello/portuguese")
@IfBuildProperty(name = "hello.language", stringValue = "portuguese")
public class HelloPortuguese {

    private static final String GREETING = "Olá";

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return GREETING;
    }
}
