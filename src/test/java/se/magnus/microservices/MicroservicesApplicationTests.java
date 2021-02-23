package se.magnus.microservices;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.junit.jupiter.api.Test;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ConfigurableApplicationContext;

@SpringBootTest
public class MicroservicesApplicationTests {

	private static final Logger LOG = LoggerFactory.getLogger(MicroservicesApplication.class);


	@Test
	void contextLoads() {
		ConfigurableApplicationContext ctx = SpringApplication.run(MicroservicesApplication.class);

		String mongoDbHost = ctx.getEnvironment().getProperty("spring.data.mongodb.host");
		String mongoDbPort = ctx.getEnvironment().getProperty("spring.data.mongodb.port");
		LOG.info("Connected to MongoDb: " + mongoDbHost + ":" + mongoDbPort);
		System.out.println("Connected to MongoDb: " + mongoDbHost + ":" + mongoDbPort);

		String postgreSqlUri = ctx.getEnvironment().getProperty("spring.datasource.url");
		LOG.info("Connected to PostgreSQL: " + postgreSqlUri);
		System.out.println("Connected to PostgreSQL: " + postgreSqlUri);

	}

} 
