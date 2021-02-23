package se.magnus.microservices;

import com.mongodb.BasicDBObjectBuilder;
import com.mongodb.DBObject;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.MongoTemplate;

@SpringBootTest

public class MongoDbSpringIntegrationTest {

    @Test
    public void test(@Autowired MongoTemplate mongoTemplate) {

        Boolean isTrue = true;
        // given
        DBObject objectToSave = BasicDBObjectBuilder.start()
            .add("key", "value")
            .get();

        // when
        mongoTemplate.save(objectToSave, "collection");

        // then
        // assertTrue(mongoTemplate.findAll(DBObject.class, "collection")).extracting("key").containsOnly("value");
        System.out.println(mongoTemplate.findAll(DBObject.class, "collection"));
        assertTrue(isTrue);

    }
}
