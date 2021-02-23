package se.magnus.microservices.product.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.web.bind.annotation.RestController;
import se.magnus.microservices.product.Product;
import se.magnus.microservices.product.ProductService;
import se.magnus.microservices.product.persistence.ProductEntity;
import se.magnus.microservices.product.persistence.ProductRepository;
import se.magnus.microservices.util.exceptions.InvalidInputException;
import se.magnus.microservices.util.exceptions.NotFoundException;
import se.magnus.microservices.util.http.ServiceUtil;

@RestController
public class ProductServiceImpl implements ProductService {

    private static final Logger LOG = LoggerFactory.getLogger(ProductServiceImpl.class);

    private final ServiceUtil serviceUtil;

    private final ProductRepository repository;

    private final ProductMapper mapper;

    @Autowired
    public ProductServiceImpl(ProductRepository repository, ProductMapper mapper, ServiceUtil serviceUtil) {
        this.repository = repository;
        this.mapper = mapper;
        this.serviceUtil = serviceUtil;
    }

    @Override
    public Product createProduct(Product body) {
        try {
            ProductEntity entity = mapper.apiToEntity(body);
            ProductEntity newEntity = repository.save(entity);

            LOG.debug("createProduct: entity created for productId: {}", body.getProductId());
            return mapper.entityToApi(newEntity);

        } catch (DuplicateKeyException dke) {
            throw new InvalidInputException("Duplicate key, Product Id: " + body.getProductId());
        }
    }

    @Override
    public Product getProduct(int productId) {

        LOG.debug("/product return the found product for productId={}", productId);

        if (productId < 1)
            throw new InvalidInputException("Invalid productId: " + productId);

        if (productId == 13)
            throw new NotFoundException("No product found for productId: " + productId);

        ProductEntity entity = repository.findByProductId(productId).orElseThrow(NotFoundException::new);

        Product response = mapper.entityToApi(entity);
        response.setServiceAddress(serviceUtil.getServiceAddress());

        LOG.debug("getProduct: found productId: {}", response.getProductId());

        return response;
    }

    @Override
    public void deleteProduct(int productId) {
        LOG.debug("deleteProduct: tries to delete an entity with productId: {}", productId);

        repository.findByProductId(productId).ifPresent(e -> repository.delete(e));
    }

}