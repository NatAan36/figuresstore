-- =====================================================================
-- Atelier Hobby: E-Commerce Figure
-- PRD v1.0, Section 6: Relational Database Design
-- Engine: MySQL 8.0+ / InnoDB, charset utf8mb4
-- Covers the 10 tables explicitly defined in PRD section 6.1
-- =====================================================================

CREATE DATABASE IF NOT EXISTS atelier_hobby
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE atelier_hobby;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS order_items, orders, wishlists, cart_items, carts,
                     products, categories, brands, banners, users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  username       VARCHAR(50)     NOT NULL,
  email          VARCHAR(255)    NOT NULL,
  password_hash  VARCHAR(255)    NOT NULL COMMENT 'bcrypt/argon2 hash, never plain text',
  role           ENUM('customer','super_admin','store_manager',
                      'warehouse_staff','customer_service')
                 NOT NULL DEFAULT 'customer',
  created_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- brands (manufacturers, e.g. Good Smile Company, Bandai, Kotobukiya)
-- ---------------------------------------------------------------------
CREATE TABLE brands (
  brand_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  name      VARCHAR(100)  NOT NULL,
  url       VARCHAR(255)  NULL,
  PRIMARY KEY (brand_id),
  UNIQUE KEY uq_brands_name (name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- categories
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  category_id    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  name           VARCHAR(100)  NOT NULL,
  slug           VARCHAR(120)  NOT NULL COMMENT 'SEO-friendly URL, e.g. scale-figure',
  icon_url       VARCHAR(255)  NULL,
  display_order  INT           NOT NULL DEFAULT 0,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_categories_slug (slug)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- products
-- ---------------------------------------------------------------------
CREATE TABLE products (
  product_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  brand_id          INT UNSIGNED    NOT NULL,
  category_id       INT UNSIGNED    NOT NULL,
  sku               VARCHAR(64)     NOT NULL,
  name              VARCHAR(255)    NOT NULL,
  slug              VARCHAR(280)    NOT NULL,
  series_title      VARCHAR(255)    NULL COMMENT 'Franchise / series, e.g. anime or game title',
  description       TEXT            NULL,
  price             DECIMAL(15,2)   NOT NULL COMMENT 'IDR',
  discount_price    DECIMAL(15,2)   NULL     COMMENT 'IDR, NULL = no discount',
  status            ENUM('available','pre_order','coming_soon','out_of_stock')
                    NOT NULL DEFAULT 'available',
  is_new            TINYINT(1)      NOT NULL DEFAULT 0,
  has_bonus         TINYINT(1)      NOT NULL DEFAULT 0,
  stock_qty         INT UNSIGNED    NOT NULL DEFAULT 0,
  est_arrival_text  VARCHAR(100)    NULL COMMENT 'e.g. "Q2 2027" for pre-order items',
  main_image_url    VARCHAR(255)    NULL,
  PRIMARY KEY (product_id),
  UNIQUE KEY uq_products_sku (sku),
  UNIQUE KEY uq_products_slug (slug),
  KEY idx_products_brand (brand_id),
  KEY idx_products_category (category_id),
  KEY idx_products_status (status),
  CONSTRAINT fk_products_brand
    FOREIGN KEY (brand_id) REFERENCES brands (brand_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories (category_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_products_price CHECK (price >= 0),
  CONSTRAINT chk_products_discount
    CHECK (discount_price IS NULL OR (discount_price >= 0 AND discount_price <= price))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- carts (1 user : 1 cart)
-- ---------------------------------------------------------------------
CREATE TABLE carts (
  cart_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NOT NULL,
  updated_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (cart_id),
  UNIQUE KEY uq_carts_user (user_id),
  CONSTRAINT fk_carts_user
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- cart_items
-- ---------------------------------------------------------------------
CREATE TABLE cart_items (
  citem_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  cart_id     BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT UNSIGNED NOT NULL,
  quantity    INT UNSIGNED    NOT NULL DEFAULT 1,
  added_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (citem_id),
  UNIQUE KEY uq_cart_items_cart_product (cart_id, product_id),
  KEY idx_cart_items_product (product_id),
  CONSTRAINT fk_cart_items_cart
    FOREIGN KEY (cart_id) REFERENCES carts (cart_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_cart_items_product
    FOREIGN KEY (product_id) REFERENCES products (product_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT chk_cart_items_qty CHECK (quantity > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- wishlists (junction: users <-> products, many-to-many)
-- ---------------------------------------------------------------------
CREATE TABLE wishlists (
  wish_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT UNSIGNED NOT NULL,
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (wish_id),
  UNIQUE KEY uq_wishlists_user_product (user_id, product_id),
  KEY idx_wishlists_product (product_id),
  CONSTRAINT fk_wishlists_user
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_wishlists_product
    FOREIGN KEY (product_id) REFERENCES products (product_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- orders (1 user : many orders)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  order_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id           BIGINT UNSIGNED NOT NULL,
  order_number      VARCHAR(32)     NOT NULL,
  order_type        ENUM('ready_stock','pre_order') NOT NULL DEFAULT 'ready_stock',
  total_amount      DECIMAL(15,2)   NOT NULL COMMENT 'IDR',
  payment_method    VARCHAR(50)     NULL COMMENT 'e.g. VA_BCA, QRIS, GOPAY, CREDIT_CARD',
  payment_status    ENUM('pending','paid','failed','expired','refunded')
                    NOT NULL DEFAULT 'pending',
  order_status      ENUM('awaiting_payment','paid','processing','packed','shipped',
                         'completed','cancelled','return_requested','returned',
                         'preorder_confirmed','awaiting_arrival','awaiting_settlement')
                    NOT NULL DEFAULT 'awaiting_payment',
  shipping_address  TEXT            NOT NULL COMMENT 'Address snapshot at order time',
  created_at        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (order_id),
  UNIQUE KEY uq_orders_number (order_number),
  KEY idx_orders_user_created (user_id, created_at),
  KEY idx_orders_status (order_status),
  CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_orders_total CHECK (total_amount >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- order_items
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
  oitem_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id    BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT UNSIGNED NOT NULL,
  unit_price  DECIMAL(15,2)   NOT NULL COMMENT 'Price snapshot at order time',
  quantity    INT UNSIGNED    NOT NULL,
  subtotal    DECIMAL(15,2)   GENERATED ALWAYS AS (unit_price * quantity) STORED,
  PRIMARY KEY (oitem_id),
  KEY idx_order_items_order (order_id),
  KEY idx_order_items_product (product_id),
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products (product_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_order_items_qty CHECK (quantity > 0),
  CONSTRAINT chk_order_items_price CHECK (unit_price >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- banners (homepage hero carousel, managed from admin panel)
-- ---------------------------------------------------------------------
CREATE TABLE banners (
  banner_id   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  title       VARCHAR(150)  NOT NULL,
  image_url   VARCHAR(255)  NOT NULL,
  target_url  VARCHAR(255)  NULL,
  sort_order  INT           NOT NULL DEFAULT 0,
  is_active   TINYINT(1)    NOT NULL DEFAULT 1,
  PRIMARY KEY (banner_id),
  KEY idx_banners_active_sort (is_active, sort_order)
) ENGINE=InnoDB;
