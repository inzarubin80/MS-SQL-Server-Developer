Select ord.CustomerID, det.StockItemID, SUM(det.UnitPrice), SUM(det.Quantity), COUNT(ord.OrderID)
FROM Sales.Orders AS ord
JOIN Sales.OrderLines AS det
ON det.OrderID = ord.OrderID
JOIN Sales.Invoices AS Inv
ON Inv.OrderID = ord.OrderID
JOIN Sales.CustomerTransactions AS Trans

ON Trans.InvoiceID = Inv.InvoiceID


--JOIN Warehouse.StockItemTransactions AS ItemTrans Лишнее соедниенение не используется
--ON ItemTrans.StockItemID = det.StockItemID


WHERE Inv.BillToCustomerID != ord.CustomerID

AND (Select SupplierId
FROM Warehouse.StockItems AS It
Where It.StockItemID = det.StockItemID) = 12



AND (SELECT SUM(Total.UnitPrice*Total.Quantity)
FROM Sales.OrderLines AS Total
Join Sales.Orders AS ordTotal
On ordTotal.OrderID = Total.OrderID
WHERE ordTotal.CustomerID = Inv.CustomerID) > 250000


--AND DATEDIFF(dd, Inv.InvoiceDate, ord.OrderDate) = 0 так как тип полей date  тогда вычисление разницы лишняя операция и достаточно проверить на равенство
AND Inv.InvoiceDate = ord.OrderDate 


GROUP BY ord.CustomerID, det.StockItemID
ORDER BY ord.CustomerID, det.StockItemID
Go

--Запрос работает на 20% быстрее (40/60)