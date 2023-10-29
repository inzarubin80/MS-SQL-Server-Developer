Use WideWorldImporters;

--1. 
--Написать функцию возвращающую Клиента с наибольшей суммой покупки.
Go
DROP FUNCTION IF EXISTS GetCustomerMaxSum

Go
CREATE FUNCTION GetCustomerMaxSum()
RETURNS INT
AS
BEGIN
    DECLARE @CustomerId INT
    Select top 1
        @CustomerId = i.CustomerID
    from
        Sales.InvoiceLines as il
        left join Sales.Invoices as i
        on il.InvoiceID = i.InvoiceID
    group by
CustomerID
    order by
sum(UnitPrice * Quantity)  desc
    RETURN @CustomerId
END


Go
Select dbo.GetCustomerMaxSum() as MaxSum


--2
--Написать хранимую процедуру с входящим параметром СustomerID, выводящую сумму покупки по этому клиенту.
--Использовать таблицы :
--Sales.Customers
--Sales.Invoices
--Sales.InvoiceLines
--Use WideWorldImporters;
Go


drop procedure if EXISTS GetCustomerPurchaseAmount

GO  
Create PROCEDURE GetCustomerPurchaseAmount
    @CustomerID INT
AS
BEGIN
	declare @sum int;
	SELECT @sum = isNull(SUM(il.Quantity * il.UnitPrice),0) 
    FROM Sales.Customers c
    left JOIN Sales.Invoices i ON c.CustomerID = i.CustomerID
    left JOIN Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
    WHERE c.CustomerID = @CustomerID
    GROUP BY c.CustomerID;
	return @sum
END;

Go
Declare @sum int
EXEC  @sum = GetCustomerPurchaseAmount 1
Print @sum

--3
-- Создать одинаковую функцию и хранимую процедуру, посмотреть в чем разница в производительности и почему.
--Procedure
Go
DROP Procedure IF EXISTS ProcedureGetCustomerNameById

Go
CREATE Procedure ProcedureGetCustomerNameById
   @CustomerID int, 
   @CustomerName nvarchar(100) OUTPUT
AS
BEGIN
   
    Select 
       @CustomerName = Customers.CustomerName
    from
        Sales.Customers as Customers
		where
		Customers.CustomerID = @CustomerID

END



;

--Function

Go
DROP Function IF EXISTS FunctionGetCustomerNameById
;
Go
CREATE Function FunctionGetCustomerNameById(@CustomerID int) 
 RETURNS nvarchar(100)
 AS
BEGIN
   
   declare @CustomerName nvarchar(100)
    Select 
       @CustomerName = Customers.CustomerName
    from
        Sales.Customers as Customers
		where
		Customers.CustomerID = @CustomerID

		return @CustomerName

END
;
Go
Select dbo.FunctionGetCustomerNameById(1) as Name


Go
Declare @CustomerName nvarchar(100)
Exec
ProcedureGetCustomerNameById 1, @CustomerName OUTPUT
Print @CustomerName

--Обычно хранимые процедуры имеют небольшое преимущество в производительности по сравнению с функциями


-- 4 Создайте табличную функцию покажите как ее можно вызвать для каждой строки result set'а без использования цикла.


Go
DROP FUNCTION IF EXISTS dbo.StockItemInfo

Go
CREATE FUNCTION dbo.StockItemInfo
(
    @StockItemID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT StockItems.StockItemName
    FROM [Warehouse].[StockItems] as StockItems
    WHERE StockItems.StockItemID = @StockItemID
);


GO

SELECT 
InvoiceLines.InvoiceLineID,
StockItemID.StockItemName as StockItemName
FROM Sales.InvoiceLines as InvoiceLines
CROSS APPLY dbo.StockItemInfo(InvoiceLines.StockItemID) StockItemID;


