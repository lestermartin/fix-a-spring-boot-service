# fix-a-spring-boot-service

**This is a buggy version of [lestermartin/build-a-spring-boot-service](https://github.com/lestermartin/build-a-spring-boot-service) that can be used as a problem-solving project.**

*Multiple issues have been introduced that causes the solution to NOT work. Try to get it the project working well again so that you can use the following two functions.* 

- `POST /api/orders` — place an order
- `GET /api/orders/{orderId}/status` — check its status

## Project layout

```
pom.xml
Dockerfile
db/schema.sql                          -- DDL, run automatically by the postgres container
src/main/java/com/acme/order/
  CatalogApplication.java              -- @SpringBootApplication + @MapperScan
  domain/                              -- Order, OrderItem, OrderStatus
  mapper/OrderMapper.java              -- MyBatis mapper interface
  service/                             -- OrderService, OrderNotFoundException, PriceLookup
  web/                                 -- controller, DTOs, error handling
src/main/resources/
  application.yml
  mappers/OrderMapper.xml              -- the hand-written SQL
src/test/java/...OrderServiceTest.java -- Mockito unit test
```

`PriceLookup` is a stand-in for a real product catalog: it returns a deterministic price
per product id so totals are stable and repeatable for this demo. Swap it for a real
catalog client in a production system.


## Run it locally

Start the database:

docker build -t ecomm-postgres .
docker run -d --name epg -p 5433:5432 -v pgdata:/var/lib/postgresql/data ecomm-postgres

Then run the app against it:

```bash
mvn spring-boot:run
```

The default `application.yml` points at `localhost:5433` (port swap in `docker run` above) to prevent collision if there is already a local postgres instance running and uses the same
credentials the Dockerfile uses.

## Validating everything works

### 1. Confirm the app is healthy

```bash
curl -s http://localhost:8080/actuator/health
```

Expect: `{"status":"UP"}`

### 2. Place an order

```bash
curl -i -X POST localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "items": [{"productId": 501, "quantity": 2}, {"productId": 777, "quantity": 1}]}'
```

Expect: `HTTP/1.1 201` with a JSON body like:

```json
{"orderId": 1, "status": "PLACED", "total": 71.00}
```

Note the `orderId` returned — you'll need it for the next steps. (Totals are
deterministic given `PriceLookup`'s fixed pricing, so the same request always produces
the same total.)

### 3. Check its status

```bash
curl -i localhost:8080/api/orders/1/status
```

Expect: `HTTP/1.1 200` with `{"orderId": 1, "status": "PLACED"}`.

### 4. Confirm validation works (expect a 400)

```bash
curl -i -X POST localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": 1, "items": [{"productId": 501, "quantity": 0}]}'
```

Expect: `HTTP/1.1 400` with a body like:

```json
{"code": "INVALID_REQUEST", "message": "items[0].quantity must be greater than or equal to 1"}
```

### 5. Confirm not-found handling works (expect a 404)

```bash
curl -i localhost:8080/api/orders/999999/status
```

Expect: `HTTP/1.1 404` with `{"code": "ORDER_NOT_FOUND", "message": "Order not found: 999999"}`.

### 6. Confirm the data actually landed in Postgres

```bash
docker compose exec postgres psql -U app -d ecommerce -c \
  "SELECT o.id, o.status, o.total, oi.product_id, oi.quantity, oi.price FROM orders o JOIN order_items oi ON oi.order_id = o.id ORDER BY o.id;"
```

You should see one row per order item, matching what you posted in step 2.

### 7. Run the automated test

```bash
mvn test
```

Expect `BUILD SUCCESS` with `OrderServiceTest`'s two tests passing (mocked, no database
needed).

If every step above matches, the schema, the MyBatis mapping, the service's
transactional write, the REST layer, and the error handling are all confirmed working
together.
