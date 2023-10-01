/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "10 - Операторы изменения данных".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

/*
1. Довставлять в базу пять записей используя insert в таблицу Customers или Suppliers 
*/
INSERT INTO Sales.Customers
    ( CustomerName, BillToCustomerID, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit, AccountOpenedDate, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, DeliveryRun, RunPosition, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, PostalAddressLine1, PostalAddressLine2, PostalPostalCode, LastEditedBy)
VALUES
    ('Customer 1', 1, 1, 2, 1, NULL, 1, 10 , 10  , 1000.00, '2023-09-26', 10.000, 0, 0, 30, '123-456-7890', '123-456-7891', NULL, NULL, 'http://customer1.com', '123 Main St', NULL, '12345', '123 Main St', NULL, '12345', 1),
    ('Customer 2', 2, 2, 2, 2, NULL, 2, 10, 10, 2000.00, '2023-09-26', 20.000, 0, 0, 30, '123-456-7890', '123-456-7891', NULL, NULL, 'http://customer2.com', '456 Main St', NULL, '12345', '456 Main St', NULL, '12345', 1),
    ('Customer 3', 3, 3, 2, 3, NULL, 3, 10, 10, 3000.00, '2023-09-26', 30.000, 0, 0, 30, '123-456-7890', '123-456-7891', NULL, NULL, 'http://customer3.com', '789 Main St', NULL, '12345', '789 Main St', NULL, '12345', 1),
    ('Customer 4', 4, 4, 2, 4, NULL, 4, 10, 10, 4000.00, '2023-09-26', 40.000, 0, 0, 30, '123-456-7890', '123-456-7891', NULL, NULL, 'http://customer4.com', '321 Main St', NULL, '12345', '321 Main St', NULL, '12345', 1),
    ('Customer 5', 5, 5, 2, 5, NULL , 5 , 10 , 10 , 5000.00 , '2023-09-26' , 50.000 , 0 , 0 , 30 , '123-456-7890' , '123-456-7891' , NULL , NULL , 'http://customer5.com' , '654 Main St' , NULL , '12345' , '654 Main St' , NULL , '12345' , 1);

/*
2. Удалите одну запись из Customers, которая была вами добавлена
*/
;
DECLARE @idCustomers INT = 1073
DELETE FROM Sales.Customers
 WHERE Sales.Customers.CustomerID= @idCustomers 

/*
3. Изменить одну запись, из добавленных через UPDATE
*/
;
DECLARE @idCustomersPrew INT = 1073
SET @idCustomersPrew = 1072
UPDATE Sales.Customers SET [CustomerName]='Customer 4' WHERE CustomerID=@idCustomersPrew;

/*
4. Написать MERGE, который вставит вставит запись в клиенты, если ее там нет, и изменит если она уже есть
*/

MERGE INTO [Sales].[Customers] AS target
USING (VALUES 
    (/* CustomerID */ 1, /* CustomerName */ 'John Doe', /* BillToCustomerID */ 1, /* CustomerCategoryID */ 1, /* BuyingGroupID */ 1, /* PrimaryContactPersonID */ 1, /* AlternateContactPersonID */ 2, /* DeliveryMethodID */ 1, /* DeliveryCityID */ 1, /* PostalCityID */ 1, /* CreditLimit */ 1000.00, /* AccountOpenedDate */ '2023-09-26', /* StandardDiscountPercentage */ 0.05, /* IsStatementSent */ 0, /* IsOnCreditHold */ 0, /* PaymentDays */ 30, /* PhoneNumber */ '1234567890', /* FaxNumber */ '9876543210', /* DeliveryRun */ NULL, /* RunPosition */ NULL, /* WebsiteURL */ 'www.example.com', /* DeliveryAddressLine1 */ '123 Main St', /* DeliveryAddressLine2 */ NULL, /* DeliveryPostalCode */ '12345', /* DeliveryLocation */ NULL, /* PostalAddressLine1 */ '123 Main St', /* PostalAddressLine2 */ NULL, /* PostalPostalCode */ '12345', /* LastEditedBy */ 1)
) AS source (
    [CustomerID], [CustomerName], [BillToCustomerID], [CustomerCategoryID], [BuyingGroupID], [PrimaryContactPersonID], [AlternateContactPersonID], [DeliveryMethodID], [DeliveryCityID], [PostalCityID], [CreditLimit], [AccountOpenedDate], [StandardDiscountPercentage], [IsStatementSent], [IsOnCreditHold], [PaymentDays], [PhoneNumber], [FaxNumber], [DeliveryRun], [RunPosition], [WebsiteURL], [DeliveryAddressLine1], [DeliveryAddressLine2], [DeliveryPostalCode], [DeliveryLocation], [PostalAddressLine1], [PostalAddressLine2], [PostalPostalCode], [LastEditedBy]
) ON (target.[CustomerID] = source.[CustomerID])
WHEN MATCHED THEN
    UPDATE SET
        target.[CustomerName] = source.[CustomerName],
        target.[BillToCustomerID] = source.[BillToCustomerID],
        target.[CustomerCategoryID] = source.[CustomerCategoryID],
        target.[BuyingGroupID] = source.[BuyingGroupID],
        target.[PrimaryContactPersonID] = source.[PrimaryContactPersonID],
        target.[AlternateContactPersonID] = source.[AlternateContactPersonID],
        target.[DeliveryMethodID] = source.[DeliveryMethodID],
        target.[DeliveryCityID] = source.[DeliveryCityID],
        target.[PostalCityID] = source.[PostalCityID],
        target.[CreditLimit] = source.[CreditLimit],
        target.[AccountOpenedDate] = source.[AccountOpenedDate],
        target.[StandardDiscountPercentage] = source.[StandardDiscountPercentage],
        target.[IsStatementSent] = source.[IsStatementSent],
        target.[IsOnCreditHold] = source.[IsOnCreditHold],
        target.[PaymentDays] = source.[PaymentDays],
        target.[PhoneNumber] = source.[PhoneNumber],
        target.[FaxNumber] = source.[FaxNumber],
        target.[DeliveryRun] = source.[DeliveryRun],
        target.[RunPosition] = source.[RunPosition],
        target.[WebsiteURL] = source.[WebsiteURL],
        target.[DeliveryAddressLine1] = source.[DeliveryAddressLine1],
        target.[DeliveryAddressLine2] = source.[DeliveryAddressLine2],
        target.[DeliveryPostalCode] = source.[DeliveryPostalCode],
        target.[DeliveryLocation] = source.[DeliveryLocation],
        target.[PostalAddressLine1] = source.[PostalAddressLine1],
        target.[PostalAddressLine2] = source.[PostalAddressLine2],
        target.[PostalPostalCode] = source.[PostalPostalCode],
        target.[LastEditedBy] = source.[LastEditedBy]
WHEN NOT MATCHED THEN
    INSERT (
        [CustomerID], [CustomerName], [BillToCustomerID], [CustomerCategoryID], [BuyingGroupID], [PrimaryContactPersonID], [AlternateContactPersonID], [DeliveryMethodID], [DeliveryCityID], [PostalCityID], [CreditLimit], [AccountOpenedDate], [StandardDiscountPercentage], [IsStatementSent], [IsOnCreditHold], [PaymentDays], [PhoneNumber], [FaxNumber], [DeliveryRun], [RunPosition], [WebsiteURL], [DeliveryAddressLine1], [DeliveryAddressLine2], [DeliveryPostalCode], [DeliveryLocation], [PostalAddressLine1], [PostalAddressLine2], [PostalPostalCode], [LastEditedBy]
    )
    VALUES (
        source.[CustomerID], source.[CustomerName], source.[BillToCustomerID], source.[CustomerCategoryID], source.[BuyingGroupID], source.[PrimaryContactPersonID], source.[AlternateContactPersonID], source.[DeliveryMethodID], source.[DeliveryCityID], source.[PostalCityID], source.[CreditLimit], source.[AccountOpenedDate], source.[StandardDiscountPercentage], source.[IsStatementSent], source.[IsOnCreditHold], source.[PaymentDays], source.[PhoneNumber], source.[FaxNumber], source.[DeliveryRun], source.[RunPosition], source.[WebsiteURL], source.[DeliveryAddressLine1], source.[DeliveryAddressLine2], source.[DeliveryPostalCode], source.[DeliveryLocation], source.[PostalAddressLine1], source.[PostalAddressLine2], source.[PostalPostalCode], source.[LastEditedBy]
    );

/*
5. Напишите запрос, который выгрузит данные через bcp out и загрузить через bulk insert
*/
--выгрузит данные через bcp out
bcp Sales.Customers out "C:\Users\izarubin\MS SQL Server Developer\customers.txt" -S "NB-PF3728FS\SQL2022" -d "WideWorldImporters" -T -c
--агрузить через bulk insert
BULK INSERT [Sales].[Customers] FROM 'C:\Users\izarubin\MS SQL Server Developer\customers.txt'

