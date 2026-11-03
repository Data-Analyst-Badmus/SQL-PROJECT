

PRAGMA foreign_keys = ON;

DROP VIEW  IF EXISTS product_ratings;
DROP VIEW  IF EXISTS order_totals;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS order_details;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS suppliers;

-- Schema --

CREATE TABLE suppliers (
    supplier_id    INTEGER PRIMARY KEY,
    supplier_name  TEXT NOT NULL UNIQUE,
    country        TEXT NOT NULL                                       -- nominal
);

CREATE TABLE customers (
    customer_id        INTEGER PRIMARY KEY,
    first_name         TEXT NOT NULL,
    last_name          TEXT NOT NULL,
    email              TEXT NOT NULL UNIQUE,
    gender             TEXT NOT NULL CHECK (gender IN ('Male','Female','Other')),   -- nominal
    city               TEXT NOT NULL,                                               -- nominal
    age                INTEGER NOT NULL CHECK (age BETWEEN 18 AND 100),             -- ratio
    loyalty_level      TEXT NOT NULL
                       CHECK (loyalty_level IN ('Bronze','Silver','Gold','Platinum')),  -- ordinal
    registration_date  TEXT NOT NULL                                                -- interval
);

CREATE TABLE products (
    product_id      INTEGER PRIMARY KEY,
    product_name    TEXT NOT NULL,
    category        TEXT NOT NULL,                                     -- nominal
    supplier_id     INTEGER NOT NULL,
    price           REAL NOT NULL CHECK (price > 0),                   -- ratio
    stock_quantity  INTEGER NOT NULL CHECK (stock_quantity >= 0),      -- ratio
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE orders (
    order_id            INTEGER PRIMARY KEY,
    customer_id         INTEGER NOT NULL,
    order_date          TEXT NOT NULL,                                 -- interval
    payment_method      TEXT NOT NULL
                        CHECK (payment_method IN ('Credit Card','Debit Card','PayPal','Gift Card','Bank Transfer')),
    shipping_method     TEXT NOT NULL
                        CHECK (shipping_method IN ('Standard','Express','Next-Day','Click & Collect')),
    satisfaction_score  INTEGER CHECK (satisfaction_score BETWEEN 1 AND 5),   -- ordinal, NULL if no reply
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Links orders to products (many-to-many). Compound key: one row per product per order.
CREATE TABLE order_details (
    order_id      INTEGER NOT NULL,
    product_id    INTEGER NOT NULL,
    quantity      INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 20),  -- ratio
    unit_price    REAL NOT NULL CHECK (unit_price > 0),                -- price at time of sale
    discount_pct  REAL NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 50),
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Compound key: a customer can review a product only once.
CREATE TABLE reviews (
    customer_id  INTEGER NOT NULL,
    product_id   INTEGER NOT NULL,
    review_date  TEXT NOT NULL,
    rating       INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),      -- ordinal
    PRIMARY KEY (customer_id, product_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id)  REFERENCES products(product_id)
);

CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_orders_date       ON orders(order_date);
CREATE INDEX idx_details_product   ON order_details(product_id);
CREATE INDEX idx_products_supplier ON products(supplier_id);
CREATE INDEX idx_reviews_product   ON reviews(product_id);

-- Derived values are views, not stored columns, so they cannot go out of sync.
CREATE VIEW order_totals AS
SELECT order_id,
       COUNT(*) AS item_count,
       ROUND(SUM(quantity * unit_price * (1 - discount_pct / 100.0)), 2) AS total_amount
FROM order_details
GROUP BY order_id;

CREATE VIEW product_ratings AS
SELECT product_id, COUNT(*) AS review_count, ROUND(AVG(rating), 2) AS avg_rating
FROM reviews
GROUP BY product_id;

-- Lookup tables used only to build the data ----------------------------

CREATE TEMP TABLE first_names (id INTEGER PRIMARY KEY, name TEXT, gender TEXT);
INSERT INTO first_names (name, gender) VALUES
 ('James','Male'),('Olivia','Female'),('Mohammed','Male'),('Amelia','Female'),('Oliver','Male'),
 ('Fatima','Female'),('Noah','Male'),('Priya','Female'),('Harry','Male'),('Sophia','Female'),
 ('Ali','Male'),('Emily','Female'),('George','Male'),('Aisha','Female'),('Jack','Male'),
 ('Chloe','Female'),('Daniel','Male'),('Zara','Female'),('Liam','Male'),('Hannah','Female');

CREATE TEMP TABLE last_names (id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO last_names (name) VALUES
 ('Smith'),('Jones'),('Khan'),('Taylor'),('Brown'),('Patel'),('Wilson'),('Evans'),
 ('Ahmed'),('Thomas'),('Roberts'),('Walker'),('Wright'),('Hussain'),('Green'),('Hall'),
 ('Clarke'),('Singh'),('Lewis'),('Murphy');

-- cumulative weights out of 100, so bigger cities get more customers
CREATE TEMP TABLE cities (city TEXT, cum_weight INTEGER);
INSERT INTO cities VALUES
 ('London',22),('Manchester',32),('Birmingham',42),('Leeds',50),('Glasgow',58),
 ('Liverpool',66),('Bristol',73),('Sheffield',79),('Edinburgh',85),('Cardiff',90),
 ('Belfast',95),('Newcastle',100);

CREATE TEMP TABLE product_types (type_id INTEGER PRIMARY KEY, category TEXT, item TEXT, base_price REAL);
INSERT INTO product_types (category, item, base_price) VALUES
 ('Electronics','Headphones',60),('Electronics','Smartphone',450),('Electronics','Laptop',900),
 ('Electronics','Tablet',300),('Electronics','Smartwatch',180),
 ('Home & Kitchen','Blender',45),('Home & Kitchen','Coffee Maker',70),('Home & Kitchen','Air Fryer',90),
 ('Home & Kitchen','Vacuum Cleaner',150),('Home & Kitchen','Kettle',30),
 ('Books & Games','Novel',12),('Books & Games','Cookbook',22),('Books & Games','Textbook',55),
 ('Books & Games','Board Game',35),('Books & Games','Puzzle',18),
 ('Clothing','T-Shirt',15),('Clothing','Jeans',45),('Clothing','Jacket',85),
 ('Clothing','Sneakers',70),('Clothing','Backpack',40),
 ('Sports & Outdoors','Yoga Mat',20),('Sports & Outdoors','Dumbbell Set',55),('Sports & Outdoors','Tent',120),
 ('Sports & Outdoors','Water Bottle',12),('Sports & Outdoors','Bicycle Helmet',40),
 ('Beauty & Health','Shampoo',8),('Beauty & Health','Face Cream',25),('Beauty & Health','Vitamin Pack',15),
 ('Beauty & Health','Toothbrush Set',10),('Beauty & Health','Hair Dryer',35);

CREATE TEMP TABLE brands (brand_id INTEGER PRIMARY KEY, brand TEXT, multiplier REAL);
INSERT INTO brands (brand, multiplier) VALUES
 ('Nova',1.0),('Orbit',0.8),('Zenith',1.25),('Vertex',1.6),('Apex',2.0);

-- Suppliers ------------------------------------------------------------

INSERT INTO suppliers (supplier_name, country) VALUES
 ('GlobalTech Ltd','China'),('HomeStyle Supplies','United Kingdom'),
 ('PageTurner Distribution','United Kingdom'),('UrbanWear Co','Turkey'),
 ('ActiveLife Sports','Germany'),('PureGlow Beauty','France'),
 ('Pacific Imports','Vietnam'),('Nordic Goods AB','Sweden'),
 ('Delta Wholesale','Poland'),('Sunrise Trading','India');

-- Customers (1000) -----------------------------------------------------

CREATE TEMP TABLE stg_customers AS
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 1000)
SELECT n,
       abs(random() % 20) + 1 AS fn_id,
       abs(random() % 20) + 1 AS ln_id,
       abs(random() % 100)    AS gender_r,
       abs(random() % 100)    AS city_r,
       abs(random() % 18)     AS a1,     -- three draws added together give a bell-shaped age
       abs(random() % 18)     AS a2,
       abs(random() % 18)     AS a3,
       abs(random() % 100)    AS loy_r,
       abs(random() % 2000)   AS reg_days
FROM seq;

INSERT INTO customers
       (customer_id, first_name, last_name, email, gender, city, age, loyalty_level, registration_date)
SELECT s.n,
       f.name,
       l.name,
       lower(f.name) || '.' || lower(l.name) || s.n || '@example.com',
       CASE WHEN s.gender_r < 96 THEN f.gender ELSE 'Other' END,
       (SELECT city FROM cities WHERE cum_weight > s.city_r ORDER BY cum_weight LIMIT 1),
       18 + s.a1 + s.a2 + s.a3,
       CASE WHEN s.loy_r < 45 THEN 'Bronze'
            WHEN s.loy_r < 75 THEN 'Silver'
            WHEN s.loy_r < 92 THEN 'Gold'
            ELSE 'Platinum' END,
       date('2021-01-01', '+' || s.reg_days || ' days')
FROM stg_customers s
JOIN first_names f ON f.id = s.fn_id
JOIN last_names  l ON l.id = s.ln_id;

-- Products (150 = 30 types x 5 brands) ---------------------------------

CREATE TEMP TABLE stg_products AS
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 150)
SELECT n,
       abs(random() % 21)     AS jitter_r,
       abs(random() % 10) + 1 AS supplier_r,
       abs(random() % 100000) AS stock_r
FROM seq;

INSERT INTO products (product_id, product_name, category, supplier_id, price, stock_quantity)
SELECT p.n,
       b.brand || ' ' || t.item,
       t.category,
       p.supplier_r,
       CAST(t.base_price * b.multiplier * (0.9 + p.jitter_r / 100.0) AS INT) + 0.99,
       CASE WHEN p.stock_r % 100 < 5 THEN 0 ELSE (p.stock_r / 100) % 500 + 1 END
FROM stg_products p
JOIN product_types t ON t.type_id  = (p.n - 1) % 30 + 1
JOIN brands        b ON b.brand_id = (p.n - 1) / 30 + 1;

-- Orders (3000) --------------------------------------------------------

CREATE TEMP TABLE stg_orders AS
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 3000)
SELECT n,
       abs(random() % 1000000) / 1000000.0 AS cust_r,
       abs(random() % 1000000) / 1000000.0 AS date_r,
       abs(random() % 100) AS pay_r,
       abs(random() % 100) AS ship_r,
       abs(random() % 100) AS sat_r
FROM seq;

-- Sorted by date so order_id rises over time. The customer pick is skewed so some customers
-- order more than others, and an order is always dated after the customer registered.
INSERT INTO orders (customer_id, order_date, payment_method, shipping_method, satisfaction_score)
SELECT c.customer_id,
       date(c.registration_date,
            '+' || CAST(s.date_r * (julianday('2026-10-31') - julianday(c.registration_date)) AS INT) || ' days'),
       CASE WHEN s.pay_r < 40 THEN 'Credit Card'
            WHEN s.pay_r < 65 THEN 'Debit Card'
            WHEN s.pay_r < 90 THEN 'PayPal'
            WHEN s.pay_r < 95 THEN 'Gift Card'
            ELSE 'Bank Transfer' END,
       CASE WHEN s.ship_r < 60 THEN 'Standard'
            WHEN s.ship_r < 85 THEN 'Express'
            WHEN s.ship_r < 95 THEN 'Next-Day'
            ELSE 'Click & Collect' END,
       CASE WHEN s.sat_r < 25 THEN NULL
            WHEN s.sat_r < 35 THEN 1
            WHEN s.sat_r < 45 THEN 2
            WHEN s.sat_r < 60 THEN 3
            WHEN s.sat_r < 80 THEN 4
            ELSE 5 END
FROM stg_orders s
JOIN customers c
  ON c.customer_id = 1 + CAST(((s.cust_r + s.cust_r * s.cust_r) / 2.0) * 1000 AS INT)
ORDER BY 2;

-- Order details ----------------------------------------------------------
-- Each order has 1 to 5 items. Extra items come from the same category as the first item 45%
-- of the time, which gives association rule mining a real pattern to find.

CREATE TEMP TABLE slots (slot INTEGER);
INSERT INTO slots VALUES (1),(2),(3),(4),(5);

CREATE TEMP TABLE stg_basket AS
SELECT order_id,
       abs(random() % 100)                 AS k_r,
       abs(random() % 1000000) / 1000000.0 AS r_first
FROM orders;

CREATE TEMP TABLE stg_items AS
SELECT b.order_id,
       sl.slot,
       1 + CAST(((b.r_first + b.r_first * b.r_first) / 2.0) * 150 AS INT) AS first_pid,
       abs(random() % 100)                 AS mode_r,
       abs(random() % 5)                   AS t_r,
       abs(random() % 5)                   AS s_r,
       abs(random() % 1000000) / 1000000.0 AS pop_r,
       abs(random() % 100)                 AS qty_r,
       abs(random() % 100)                 AS disc_r
FROM stg_basket b
JOIN slots sl
  ON sl.slot <= CASE WHEN b.k_r < 35 THEN 1
                     WHEN b.k_r < 60 THEN 2
                     WHEN b.k_r < 80 THEN 3
                     WHEN b.k_r < 92 THEN 4
                     ELSE 5 END;

-- OR IGNORE skips a repeated product within the same order (rejected by the compound key)
INSERT OR IGNORE INTO order_details (order_id, product_id, quantity, unit_price, discount_pct)
SELECT i.order_id,
       p.product_id,
       CASE WHEN i.qty_r < 60 THEN 1
            WHEN i.qty_r < 85 THEN 2
            WHEN i.qty_r < 95 THEN 3
            ELSE 4 + (i.qty_r % 2) END,
       p.price,
       -- promo discount plus a loyalty bonus for Gold and Platinum members
       (CASE WHEN i.disc_r < 55 THEN 0 WHEN i.disc_r < 75 THEN 5 WHEN i.disc_r < 90 THEN 10 ELSE 15 END)
       + (CASE c.loyalty_level WHEN 'Gold' THEN 5 WHEN 'Platinum' THEN 10 ELSE 0 END)
FROM stg_items i
JOIN orders    o ON o.order_id    = i.order_id
JOIN customers c ON c.customer_id = o.customer_id
JOIN products  p ON p.product_id  =
     CASE
       WHEN i.slot = 1 THEN i.first_pid
       WHEN i.mode_r < 45 THEN i.s_r * 30 + (((i.first_pid - 1) % 30) / 5) * 5 + i.t_r + 1
       ELSE 1 + CAST(((i.pop_r + i.pop_r * i.pop_r) / 2.0) * 150 AS INT)
     END;

-- Reviews ----------------------------------------------------------------
-- About a quarter of purchases get a review, written 1 to 30 days after the order.

CREATE TEMP TABLE stg_reviews AS
SELECT order_id, product_id,
       abs(random() % 100)    AS keep_r,
       abs(random() % 30) + 1 AS delay_r,
       abs(random() % 100)    AS rating_r
FROM order_details;

INSERT OR IGNORE INTO reviews (customer_id, product_id, review_date, rating)
SELECT o.customer_id,
       s.product_id,
       min(date(o.order_date, '+' || s.delay_r || ' days'), '2026-10-31'),
       CASE WHEN s.rating_r < 6  THEN 1
            WHEN s.rating_r < 14 THEN 2
            WHEN s.rating_r < 30 THEN 3
            WHEN s.rating_r < 65 THEN 4
            ELSE 5 END
FROM stg_reviews s
JOIN orders o ON o.order_id = s.order_id
WHERE s.keep_r < 25
ORDER BY o.order_date;

DROP TABLE stg_customers; DROP TABLE stg_products; DROP TABLE stg_orders;
DROP TABLE stg_basket;    DROP TABLE stg_items;    DROP TABLE stg_reviews;
DROP TABLE slots;         DROP TABLE first_names;  DROP TABLE last_names;
DROP TABLE cities;        DROP TABLE product_types; DROP TABLE brands;

-- Checks (uncomment one at a time) --
-- SELECT 'customers', COUNT(*) FROM customers UNION ALL SELECT 'orders', COUNT(*) FROM orders
--   UNION ALL SELECT 'order_details', COUNT(*) FROM order_details UNION ALL SELECT 'reviews', COUNT(*) FROM reviews;
-- PRAGMA foreign_key_check;
-- SELECT p.category, ROUND(SUM(d.quantity * d.unit_price * (1 - d.discount_pct / 100.0)), 2) AS revenue
--   FROM order_details d JOIN products p USING (product_id) GROUP BY p.category ORDER BY revenue DESC;
-- SELECT a.product_id, b.product_id, COUNT(*) AS together FROM order_details a
--   JOIN order_details b ON a.order_id = b.order_id AND a.product_id < b.product_id
--   GROUP BY 1, 2 ORDER BY together DESC LIMIT 10;