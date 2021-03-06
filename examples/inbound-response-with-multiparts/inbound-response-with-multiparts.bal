import ballerina/http;
import ballerina/mime;
import ballerina/io;

//Creating an endpoint for the client.
endpoint http:Client clientEP {
    targets:[{url:"http://localhost:9092"}]
};

// Creating a listener for the service.
endpoint http:Listener multipartEP {
    port:9090
};

// Binding the listener to the service.
@http:ServiceConfig {basePath:"/multiparts"}
service<http:Service> test bind multipartEP {
@http:ResourceConfig {
        methods:["GET"],
        path:"/decode_in_response"
    }
    // This resource accepts multipart responses.
     receiveMultiparts (endpoint conn, http:Request request) {
        http:Request outRequest = new;
        http:Response inResponse = new;
        // Extract the bodyparts from the response.
        var returnResult = clientEP -> get("/multiparts/encode_out_response", outRequest);
        http:Response res = new;
        match returnResult {
            // Setting the error response in-case of an error
            http:HttpConnectorError connectionErr => {
                res.statusCode = 500;
                res.setStringPayload("Connection error");
            }
            http:Response returnResponse => {
                match returnResponse.getMultiparts() {
                    mime:EntityError err => {
                        res.statusCode = 500;
                        res.setStringPayload(err.message);
                    }
                    mime:Entity[] parentParts => {
                        int i = 0;
                        //Loop through body parts.
                        while (i < lengthof parentParts) {
                            mime:Entity parentPart = parentParts[i];
                            handleNestedParts(parentPart);
                            i = i + 1;
                        }
                        res.setStringPayload("Body Parts Received!");
                    }
                }
            }
        }
        _ = conn -> respond(res);
    }
}

//Get the child parts that is nested within a parent.
function handleNestedParts (mime:Entity parentPart) {
    string contentTypeOfParent = parentPart.contentType.toString();
    if (contentTypeOfParent.hasPrefix("multipart/")) {
        match parentPart.getBodyParts() {
            mime:EntityError err => {
                io:println("Error retrieving child parts!");
            }
            mime:Entity[] childParts => {
                int i = 0;
                io:println("Nested Parts Detected!");
                while (i < lengthof childParts) {
                    mime:Entity childPart = childParts[i];
                    handleContent(childPart);
                    i = i + 1;
                }
            }
        }
    }
}

@Description {value:"The content logic that handles the body parts vary based on your requirement."}
function handleContent (mime:Entity bodyPart) {
    string contentType = bodyPart.contentType.toString();
    if (mime:APPLICATION_XML == contentType || mime:TEXT_XML == contentType) {
        //Extract xml data from body part and print.
        var payload = bodyPart.getXml();
        match payload {
            mime:EntityError err => io:println("Error in getting xml payload");
            xml xmlContent => io:println(xmlContent);
        }
    } else if (mime:APPLICATION_JSON == contentType) {
        //Extract json data from body part and print.
        var payload = bodyPart.getJson();
        match payload {
            mime:EntityError err => io:println("Error in getting json payload");
            json jsonContent => io:println(jsonContent);
        }
    } else if (mime:TEXT_PLAIN == contentType) {
        //Extract text data from body part and print.
        var payload = bodyPart.getText();
        match payload {
            mime:EntityError err => io:println("Error in getting string payload");
            string textContent => io:println(textContent);
        }
    }
}
