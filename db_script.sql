-- Create Tables
-- Create Customers table
CREATE TABLE Customers (
    Customer# NUMBER(4) PRIMARY KEY,
    FirstName VARCHAR2(50),
    LastName VARCHAR2(50),
    Address VARCHAR2(50),
    City VARCHAR2(20),
    Province VARCHAR2(2),
    PostalCode VARCHAR2(15),
    Email VARCHAR2(30),
    Phone# VARCHAR2(15),
    Username VARCHAR2(15),
    HashedPassword VARCHAR2(50),
    Cookie NUMBER(4) DEFAULT 0
);

-- Create Products table
CREATE TABLE Products (
    Product# NUMBER(5) PRIMARY KEY,
    Name VARCHAR2(100),
    Description VARCHAR2(500),
    Category VARCHAR2(50),
    UnitPrice NUMBER(6,2),
    RetailPrice NUMBER(6,2),
    Stock NUMBER(4) DEFAULT 0,
    Ordered NUMBER(4) DEFAULT 0,
    Discount NUMBER(5,2)
);

-- Create OrderStatus table (a Reference table)
CREATE TABLE OrderStatus(
   OrderStatus# NUMBER(1) PRIMARY KEY,
    StatusDesc VARCHAR2(50)
);


-- Create Orders table
CREATE TABLE Orders (
    Order# NUMBER(4) PRIMARY KEY,
    Customer# NUMBER(4),
    OrderStatus# NUMBER(1) DEFAULT 1,
    OrderDate DATE,
    ShipDate DATE,
    ShipAddress VARCHAR2(50),
    ShipCity VARCHAR2(20),
    ShipProvince VARCHAR2(2),
    ShipPostal VARCHAR2(15),
    CONSTRAINT fk_customer FOREIGN KEY (Customer#) REFERENCES Customers(Customer#),
     CONSTRAINT fk_orderstatus FOREIGN KEY (OrderStatus#) REFERENCES OrderStatus(OrderStatus#)
);

-- Create OrderItems table
CREATE TABLE OrderItems (
    OrderItem# NUMBER(5) PRIMARY KEY,
    Order# NUMBER(5),
    Product# NUMBER(3),
    Quantity NUMBER(5),
    PaidEach NUMBER(6,2),
    CONSTRAINT fk_order_item FOREIGN KEY (Order#) REFERENCES Orders(Order#),
    CONSTRAINT fk_product_item FOREIGN KEY (Product#) REFERENCES Products(Product#)
);

-- Create Payment table
CREATE TABLE Payment (
    Invoice# NUMBER(6) PRIMARY KEY,
    Order# NUMBER(4),
    Amount NUMBER(8,2),
    Subtotal NUMBER(7,2),
    ShipCost NUMBER(5,2),
    PayStatus VARCHAR2(50) DEFAULT 'Not Paid',
    PayDate DATE,
    PayMethod VARCHAR2(50),
    CONSTRAINT fk_order_payment FOREIGN KEY (Order#) REFERENCES Orders(Order#)
);

-- Create sequence for Order#
CREATE SEQUENCE order_seq START WITH 1001 INCREMENT BY 1;
-- Create sequence for OrderItem#
CREATE SEQUENCE orderitem_seq START WITH 10001 INCREMENT BY 1;
-- Create sequence for Invoice#
CREATE SEQUENCE invoice_seq START WITH 100001 INCREMENT BY 1;

-- Indexes for Frequent Tables
-- Customers Table
CREATE INDEX idx_customers_lname ON Customers(LastName);

CREATE INDEX idx_customers_city_state ON Customers(City, Province);

-- Products Table
CREATE INDEX idx_products_name ON Products(Name);

CREATE INDEX idx_products_category ON Products(Category);

-- Orders Table
CREATE INDEX idx_orders_customer_date ON Orders(Customer#, OrderDate);

-- Payment Table
CREATE INDEX idx_payment_order ON Payment(Order#);

CREATE INDEX idx_payment_paydate ON Payment(PayDate);

-- Triggers
-- Trigger for Updating Order as Customer Confirms to Pay for Order (Invoice Generation)
CREATE OR REPLACE TRIGGER update_order_on_confirm_trg
AFTER INSERT ON Payment
FOR EACH ROW    
BEGIN
    UPDATE Orders
    	SET OrderStatus# = 2
    	WHERE Order# = :NEW.Order#;
END;
/

-- Trigger for Updating Order on Payment
CREATE OR REPLACE TRIGGER update_order_on_payment_trg
AFTER UPDATE OF PayStatus ON Payment
FOR EACH ROW
WHEN (OLD.PayStatus = 'Not Paid' AND NEW.PayStatus = 'Paid')
BEGIN
    UPDATE Orders
    	SET OrderStatus# = 3, OrderDate = :NEW.PayDate
    	WHERE Order# = :NEW.Order#;
END;
/
-- Functions
--Function to Retrieve Customer Information:
CREATE OR REPLACE FUNCTION get_customer_info_sf(p_customer_id IN NUMBER)
RETURN VARCHAR2
AS
  lv_customer_info VARCHAR2(500);
BEGIN
  SELECT LastName || ', ' || FirstName || ' - ' || Address
      INTO lv_customer_info
      FROM Customers
      WHERE Customer# = p_customer_id;
  RETURN lv_customer_info;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 'Customer not found';
  WHEN OTHERS THEN
    RETURN 'An error occurred';
END;
/
--Functions for Products:
--Function to Retrieve Product Information:
CREATE OR REPLACE FUNCTION get_product_info_sf(p_product_id IN NUMBER)
RETURN VARCHAR2
AS
  lv_product_info VARCHAR2(500);
BEGIN
  SELECT Name || ' - ' || Description || ', $' || TO_CHAR(UnitPrice)
  INTO lv_product_info
  FROM Products
  WHERE Product# = p_product_id;

  RETURN lv_product_info;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 'Product not found';
  WHEN OTHERS THEN
    RETURN 'An error occurred';
END;
/

--Function to Calculate Order Subtotal:
CREATE OR REPLACE FUNCTION calculate_order_subtotal_sf(p_order_id IN NUMBER)
RETURN NUMBER
AS
  lv_order_subtotal NUMBER := 0;
BEGIN
  SELECT SUM(Quantity * PaidEach)
  	INTO lv_order_subtotal 
 	 FROM OrderItems
  	WHERE Order# = p_order_id;
  RETURN lv_order_subtotal;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 0;
  WHEN OTHERS THEN
    RETURN -1; -- Indicates an error
END;
/

--Function to Calculate Shipping Cost:
CREATE OR REPLACE FUNCTION calculate_ship_cost_sf (p_quantity IN NUMBER)
RETURN NUMBER 
AS
BEGIN
 IF p_quantity > 10 THEN 
    RETURN 11.00;
 ELSIF p_quantity > 5 THEN
    RETURN 8.00;
 ELSE  
    RETURN 5.00;
 END IF;
END;
/

--Function to Check if Order is Paid:
CREATE OR REPLACE FUNCTION is_order_paid(p_order_id IN NUMBER)
RETURN NUMBER
AS
  lv_order_paid NUMBER := 0;
BEGIN
  SELECT 1
  	INTO lv_order_paid
  	FROM Payment
  	WHERE Order# = p_order_id AND PayStatus = 'Paid';
  RETURN lv_order_paid;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 0;
  WHEN OTHERS THEN
    RETURN -1; -- Indicates an error
END;
/

-- Procedures
-- Procedure to Update Stock for a Product
CREATE OR REPLACE PROCEDURE update_stock_sp 
 (p_new_stock IN NUMBER, p_product_id IN NUMBER)
 AS
    CURSOR cur_stock IS
        SELECT Stock FROM Products WHERE Product# = p_product_id
        FOR UPDATE NOWAIT;
    lv_stock_num Products.Stock%TYPE;
BEGIN
    OPEN cur_stock;
    FETCH cur_stock INTO lv_stock_num;
    UPDATE Products
        SET Stock = lv_stock_num + p_new_stock
        WHERE CURRENT OF cur_stock;
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Product Not found');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/


-- Procedure to Check if Requested Number of Products Is Available in Stock
CREATE OR REPLACE PROCEDURE check_stock_sp 
 (p_requested_quantity IN NUMBER, p_product_id IN NUMBER)
 AS
    CURSOR cur_stock IS
        SELECT Stock FROM Products WHERE Product# = p_product_id;
    lv_stock_num Products.Stock%TYPE;
BEGIN
    OPEN cur_stock;
    FETCH cur_stock INTO lv_stock_num;
    IF p_requested_quantity > lv_stock_num THEN
        RAISE_APPLICATION_ERROR(-20000, 
        'Not enough in stock.  Request = '||p_requested_quantity||
        ' and stock level = '||lv_stock_num);
    END IF;
    CLOSE cur_stock;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Product Not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Procedure to Calculate PaidEach for Ordered Products 
CREATE OR REPLACE PROCEDURE calculate_paideach_sp 
 (p_order_id IN NUMBER)
 AS
    CURSOR cur_item IS
        SELECT * FROM OrderItems WHERE Order# = p_order_id
        FOR UPDATE NOWAIT;
    lv_price Products.RetailPrice%TYPE;
    lv_discount Products.Discount%TYPE;
BEGIN
    FOR rec_item in cur_item LOOP
        SELECT RetailPrice, Discount 
            INTO lv_price, lv_discount
            FROM Products
            WHERE Product# = rec_item.Product#;
        lv_price := lv_price * (1- NVL(lv_discount,0)) ;    
        UPDATE OrderItems
            SET PaidEach = lv_price
            WHERE CURRENT OF cur_item;
    END LOOP;
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Invalid Order');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Procedure to Generate Invoice for an Order
CREATE OR REPLACE PROCEDURE generate_invoice_sp
 (p_order_id IN NUMBER)
 AS
    CURSOR cur_item IS
        SELECT * FROM OrderItems WHERE Order# = p_order_id;
    lv_product_id OrderItems.Product#%TYPE;
    lv_quantity OrderItems.Quantity%TYPE;
    lv_total_quantity OrderItems.Quantity%TYPE := 0;
    lv_amount Payment.Amount%TYPE;
    lv_subtotal Payment.Subtotal%TYPE;
    lv_shipcost Payment.ShipCost%TYPE;
BEGIN
    FOR rec_item in cur_item LOOP
        lv_product_id := rec_item.Product#;
        lv_quantity := rec_item.Quantity;
        check_stock_sp (lv_quantity, lv_product_id);
        lv_total_quantity := lv_total_quantity + lv_quantity;  
    END LOOP;
    calculate_paideach_sp(p_order_id);
    lv_subtotal := calculate_order_subtotal_sf(p_order_id);
    lv_shipcost := calculate_ship_cost_sf(lv_total_quantity);
    lv_amount := lv_subtotal +  lv_shipcost;
    INSERT INTO Payment(Invoice#, Order#, Amount, Subtotal, ShipCost)
        VALUES (invoice_seq.NEXTVAL, p_order_id, lv_amount, lv_subtotal, lv_shipcost);
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Invalid Order');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Procedure to Update Payment Info After Customer Pays for an Invoice
CREATE OR REPLACE PROCEDURE receive_payment_sp
 (p_invoice_id IN NUMBER, p_date IN DATE, p_method IN VARCHAR2)
 AS
    CURSOR cur_payment IS
        SELECT * FROM Payment WHERE Invoice# = p_invoice_id
        FOR UPDATE NOWAIT;
    lv_payment Payment%ROWTYPE;
BEGIN
    OPEN cur_payment;
    FETCH cur_payment INTO lv_payment;
    UPDATE Payment
        SET PayStatus = 'Paid', PayDate = p_date, PayMethod = p_method
        WHERE CURRENT OF cur_payment;
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Invoice Not found');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Packages
-- Package Specification
CREATE OR REPLACE PACKAGE OrderManagement AS
    -- Public Procedures
    PROCEDURE generate_invoice_pp (p_order_id IN NUMBER);
END;
/
-- Package Body
CREATE OR REPLACE PACKAGE BODY OrderManagement AS
    -- Private Package Variables
    pv_product_id OrderItems.Product#%TYPE;
    pv_quantity OrderItems.Quantity%TYPE;
    pv_total_quantity OrderItems.Quantity%TYPE := 0;
    pv_amount Payment.Amount%TYPE;
    pv_subtotal Payment.Subtotal%TYPE;
    pv_shipcost Payment.ShipCost%TYPE;

    -- Private Procedures - Forward Declaration
    PROCEDURE check_stock_pp(p_requested_quantity IN NUMBER, p_product_id IN NUMBER);
    PROCEDURE calculate_paideach_pp (p_order_id IN NUMBER);

    -- Private Functions - Forward Declaration
    FUNCTION calculate_order_subtotal_pf(p_order_id IN NUMBER) RETURN NUMBER;
    FUNCTION calculate_ship_cost_pf (p_quantity IN NUMBER) RETURN NUMBER;

    -- Public Procedures
    PROCEDURE generate_invoice_pp (p_order_id IN NUMBER)
    AS
        CURSOR cur_item IS
            SELECT * FROM OrderItems WHERE Order# = p_order_id;
    BEGIN
        FOR rec_item in cur_item LOOP
            pv_product_id := rec_item.Product#;
            pv_quantity := rec_item.Quantity;
            check_stock_pp (pv_quantity, pv_product_id);
            pv_total_quantity := pv_total_quantity + pv_quantity;  
        END LOOP;
        calculate_paideach_pp(p_order_id);
        pv_subtotal := calculate_order_subtotal_pf(p_order_id);
        pv_shipcost := calculate_ship_cost_pf(pv_total_quantity);
        pv_amount := pv_subtotal +  pv_shipcost;
        INSERT INTO Payment(Invoice#, Order#, Amount, Subtotal, ShipCost)
            VALUES (invoice_seq.NEXTVAL, p_order_id, pv_amount, pv_subtotal, pv_shipcost);
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Invalid Order');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    END generate_invoice_pp;

    -- Private Procedures
    PROCEDURE check_stock_pp (p_requested_quantity IN NUMBER, p_product_id IN NUMBER)
    AS
        CURSOR cur_stock IS
            SELECT Stock FROM Products WHERE Product# = p_product_id;
        lv_stock_num Products.Stock%TYPE;
    BEGIN
        OPEN cur_stock;
        FETCH cur_stock INTO lv_stock_num;
        IF p_requested_quantity > lv_stock_num THEN
            RAISE_APPLICATION_ERROR(-20000, 
            'Not enough in stock.  Request = '||p_requested_quantity||
            ' and stock level = '||lv_stock_num);
        END IF;
        CLOSE cur_stock;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Product Not found.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    END check_stock_pp;

    PROCEDURE calculate_paideach_pp (p_order_id IN NUMBER)
    AS
        CURSOR cur_item IS
            SELECT * FROM OrderItems WHERE Order# = p_order_id
            FOR UPDATE NOWAIT;
        lv_price Products.RetailPrice%TYPE;
        lv_discount Products.Discount%TYPE;
    BEGIN
        FOR rec_item in cur_item LOOP
            SELECT RetailPrice, Discount 
                INTO lv_price, lv_discount
                FROM Products
                WHERE Product# = rec_item.Product#;
            lv_price := lv_price * (1- NVL(lv_discount,0)) ;    
            UPDATE OrderItems
                SET PaidEach = lv_price
                WHERE CURRENT OF cur_item;
        END LOOP;
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Invalid Order');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    END calculate_paideach_pp;

    -- Private Functions
    FUNCTION calculate_order_subtotal_pf (p_order_id IN NUMBER) RETURN NUMBER
    AS
    BEGIN
    SELECT SUM(Quantity * PaidEach)
        INTO pv_subtotal 
        FROM OrderItems
        WHERE Order# = p_order_id;
    RETURN pv_subtotal;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        RETURN -1; -- Indicates an error
    END calculate_order_subtotal_pf;

    FUNCTION calculate_ship_cost_pf (p_quantity IN NUMBER) RETURN NUMBER 
    AS
    BEGIN
    IF p_quantity > 10 THEN 
        RETURN 11.00;
    ELSIF p_quantity > 5 THEN
        RETURN 8.00;
    ELSE  
        RETURN 5.00;
    END IF;
    END calculate_ship_cost_pf;

END; 
/

--Insertion Data
-- Insert Min 10 Records into Customers Table
INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (1, 'John', 'Smith', '123 Main St', 'Toronto', 'ON', 'M5V 2H1', 'john.smith@gmail.com', '647-555-1234', 'johnsmith');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (2, 'Emily', 'Johnson', '456 Oak Ave', 'Vancouver', 'BC', 'V6B 3G7', 'emily.johnson@yahoo.com', '778-555-5678', 'emilyjohnson');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (3, 'Michael', 'Williams', '789 Pine Rd', 'Montreal', 'QC', 'H2Y 1Z6', 'michael.williams@gmail.com', '514-555-9876', 'michaelwilliams');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (4, 'Sophia', 'Brown', '101 Cedar Ln', 'Calgary', 'AB', 'T2P 0R2', 'sophia.brown@gmail.com', '403-555-5432', 'sophiabrown');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (5, 'Daniel', 'Miller', '234 Elm St', 'Ottawa', 'ON', 'K1P 5G8', 'daniel.miller@yahoo.com', '613-555-8765', 'danielmiller');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (6, 'Olivia', 'Davis', '567 Birch Blvd', 'Edmonton', 'AB', 'T5J 2V4', 'olivia.davis@yahoo.com', '780-555-2345', 'oliviadavis');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (7, 'Ethan', 'Wilson', '890 Maple Ave', 'Quebec City', 'QC', 'G1R 4V7', 'ethan.wilson@gmail.com', '418-555-8765', 'ethanwilson');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (8, 'Ava', 'Taylor', '111 Pineapple Cres', 'Winnipeg', 'MB', 'R3B 0N2', 'ava.taylor@gmail.com', '204-555-3456', 'avataylor');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (9, 'Logan', 'Anderson', '222 Banana Dr', 'Halifax', 'NS', 'B3H 2J2', 'logan.anderson@gmail.com', '902-555-6543', 'logananderson');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (10, 'Emma', 'White', '333 Orange Ave', 'Victoria', 'BC', 'V8W 1B5', 'emma.white@aol.com', '250-555-7890', 'emmawhite');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (11, 'Mason', 'Jones', '444 Grape St', 'Regina', 'SK', 'S4P 3X8', 'mason.jones@gmail.com', '306-555-4321', 'masonjones');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (12, 'Grace', 'Martinez', '555 Waterfront Rd', 'Charlottetown', 'PE', 'C1A 4P3', 'grace.martinez@hotmail.com', '902-555-8765', 'gracemartinez');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (13, 'Liam', 'Harris', '666 Sunset Blvd', 'St. John''s', 'NL', 'A1C 5R7', 'liam.harris@gmail.com', '709-555-2345', 'liamharris');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (14, 'Avery', 'Moore', '777 Moonlight Ln', 'Yellowknife', 'NT', 'X1A 2Z5', 'avery.moore@yahoo.com', '867-555-5678', 'averymoore');


INSERT INTO Customers (Customer#, FirstName, LastName, Address, City, Province, PostalCode, Email, Phone#, Username)
 VALUES (15, 'Ella', 'Clark', '888 Star St', 'Iqaluit', 'NU', 'X0A 1H0', 'ella.clark@gmail.com', '867-555-9876', 'ellaclark');


-- Insert Min 10 Records into Products Table
INSERT INTO Products(Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (101, 'Laptop', 'Powerful laptop for work and entertainment', 'Electronics', 1200.00, 1499.99, 50, 0, 0.05);


INSERT INTO Products(Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (102, 'Smartphone', 'High-end smartphone with advanced features', 'Electronics', 800.00, 999.99, 100, 25, 0.00);


INSERT INTO Products(Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (103, 'Shirt', 'Blue cotton shirt for men - Size M ', 'Apparel', 29.99, 39.99, 20, 3, 0.2);


INSERT INTO Products (Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (104, 'Desk Chair', 'Comfortable ergonomic chair for your office', 'Furniture', 150.00, 199.99, 20, 8, 0.1);


INSERT INTO Products (Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (105, 'Bluetooth Speaker', 'Portable speaker with wireless connectivity', 'Electronics', 50.00, 79.99, 40, 15, 0.06); 


INSERT INTO Products (Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (106, 'Cookware Set', 'High-quality non-stick cookware set for your kitchen', 'Kitchen', 120.00, 149.99, 15, 3, 0.0);


INSERT INTO Products (Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (107, 'Digital Camera', 'Professional-grade digital camera for photography enthusiasts', 'Electronics', 600.00, 799.99, 25, 7, 0.05);


INSERT INTO Products (Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (108, 'Gaming Mouse', 'High-performance gaming mouse with customizable features', 'Gaming', 40.00, 59.99, 60, 12, 0.0);


INSERT INTO Products (Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (109, 'Fitness Tracker', 'Track your fitness activities with this advanced fitness tracker', 'Fitness', 80.00, 109.99, 35, 1, 0.1);


INSERT INTO Products (Product#, Name, Description, Category, UnitPrice, RetailPrice, Stock, Ordered, Discount)
 VALUES (110, 'Blender', 'Powerful blender for smoothies and food preparation', 'Appliances', 60.00, 89.99, 45, 18, 0.05);


-- Insert Min 5 Records into OrderStatus Table
INSERT INTO OrderStatus VALUES (1, 'Order Initiated');
INSERT INTO OrderStatus VALUES (2, 'Order Invoice Generated');
INSERT INTO OrderStatus VALUES (3, 'Order Placed, Payment Received');
INSERT INTO OrderStatus VALUES (4, 'Order Processed, Sent to Shipping');
INSERT INTO OrderStatus VALUES (5, 'Order Shipped');
INSERT INTO OrderStatus VALUES (6, 'Order Cancelled');


-- Insert Min 10 Records into Orders Table
INSERT INTO Orders (Order#, Customer#) VALUES (order_seq.NEXTVAL, 1);
INSERT INTO Orders (Order#, Customer#) VALUES (order_seq.NEXTVAL, 3);
-- OrderStatus 6 : 'Order Cancelled'
INSERT INTO Orders (Order#, Customer#, OrderStatus#) VALUES (order_seq.NEXTVAL, 2, 6);
-- OrderStatus 2 : 'Order Invoice Generated'
INSERT INTO Orders (Order#, Customer#, OrderStatus#) VALUES (order_seq.NEXTVAL, 2, 2);
INSERT INTO Orders (Order#, Customer#) VALUES (order_seq.NEXTVAL, 5);
INSERT INTO Orders (Order#, Customer#) VALUES (order_seq.NEXTVAL, 4);
INSERT INTO Orders (Order#, Customer#) VALUES (order_seq.NEXTVAL, 8);
INSERT INTO Orders (Order#, Customer#) VALUES (order_seq.NEXTVAL, 6);
-- OrderStatus 3 : 'Order Placed, Payment Received'
INSERT INTO Orders (Order#, Customer#, OrderStatus#, OrderDate)
VALUES (order_seq.NEXTVAL, 10, 3, SYSDATE);
-- OrderStatus 5 : 'Order Shipped'
INSERT INTO Orders (Order#, Customer#, OrderStatus#, OrderDate, ShipDate, ShipAddress, ShipCity, ShipProvince, ShipPostal)
VALUES (order_seq.NEXTVAL, 7, 5, SYSDATE, SYSDATE + 3, '890 Maple Ave', 'Quebec City', 'QC', 'G1R 4V7');


-- Insert Min 10 Records into OrderItems Table
-- OrderItems of Orders that were just initiated
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity)
 VALUES (orderitem_seq.NEXTVAL, 1001, 101, 2);
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity)
 VALUES (orderitem_seq.NEXTVAL, 1002, 103, 2);
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity)
 VALUES (orderitem_seq.NEXTVAL, 1005, 102, 1);
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity)
 VALUES (orderitem_seq.NEXTVAL, 1006, 104, 3); 
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity)
 VALUES (orderitem_seq.NEXTVAL, 1008, 105, 2);
-- Order Items of Order#1004, Several invoices generated for this order, non paid
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity, PaidEach)
 VALUES (orderitem_seq.NEXTVAL, 1004, 103, 1, 31.99); 
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity, PaidEach)
 VALUES (orderitem_seq.NEXTVAL, 1004, 108, 2, 59.99);
--Order Items of Order#1009, Order Placed, Payment Received for this one (3 invoices generated, last one paid)
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity, PaidEach) 
 VALUES (orderitem_seq.NEXTVAL, 1009, 101, 1, 1424.04);
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity, PaidEach)
 VALUES (orderitem_seq.NEXTVAL, 1009, 108, 1, 59.99);
--Order Items of Order#1010, Order Shipped for this one (2 invoices generated, last one paid))
INSERT INTO OrderItems (OrderItem#, Order#, Product#, Quantity, PaidEach) 
 VALUES (orderitem_seq.NEXTVAL, 1010, 104, 2, 179.99);


-- Insert Min 10 Records into Payment Table
-- Invoices of Order#1004
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost)
 VALUES (invoice_seq.NEXTVAL, 1004, 36.99, 31.99, 5);
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost)
 VALUES (invoice_seq.NEXTVAL, 1004, 199.94, 191.94, 8);   
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost)
 VALUES (invoice_seq.NEXTVAL, 1004, 64.99, 59.99, 5);
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost)
 VALUES (invoice_seq.NEXTVAL, 1004, 124.98, 119.98, 5);
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost)
 VALUES (invoice_seq.NEXTVAL, 1004, 184.97, 179.97, 5);
-- Invoices of Order#1009
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost)
 VALUES (invoice_seq.NEXTVAL, 1009, 1429.05, 1424.05, 5);
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost)
 VALUES (invoice_seq.NEXTVAL, 1009, 1489.04, 1484.04, 5);
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost, PayStatus, PayDate, PayMethod)
 VALUES (invoice_seq.NEXTVAL, 1009, 1489.04, 1484.04, 5, 'Paid', SYSDATE, 'Visa Card'); 
-- Invoices of Order#1010
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost)
 VALUES (invoice_seq.NEXTVAL, 1010, 184.99, 179.99, 5);
INSERT INTO Payment (Invoice#, Order#, Amount, Subtotal, ShipCost, PayStatus, PayDate, PayMethod)
 VALUES (invoice_seq.NEXTVAL, 1010, 364.98, 359.98, 5, 'Paid', SYSDATE, 'Master Card');
