package example.quarkus.layered.single;

import io.quarkus.arc.properties.IfBuildProperty;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello/italian")
@IfBuildProperty(name = "hello.language", stringValue = "italian")
public class HelloItalian {

    private static final String GREETING = "Ciao";

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return GREETING;
    }
}
