-- =============================================    
DECLARE 
    @BeginPeriod DATETIME = '20230901',
    @EndPeriod DATETIME = '20230930 23:59:59',
    @IDList NVARCHAR(MAX) = '[{"ID": "11717328657350"}]',
    @Portion TINYINT = 0;

	SET STATISTICS XML OFF;

    DECLARE @TurnMetrics TINYINT = 0;
    DECLARE @StartOperation DATETIME = GETDATE();
    DROP TABLE IF EXISTS #IDList;
    CREATE TABLE #IDList
    (
        ID BIGINT NOT NULL
    );
    CREATE UNIQUE CLUSTERED INDEX ID ON #IDList (ID);

    IF ISNULL(ISJSON(@IDList), 0) = 1
    BEGIN
        INSERT #IDList
        (
            ID
        )
        SELECT DISTINCT
               d.ID AS ID
        FROM
            OPENJSON(@IDList)
            WITH
            (
                id BIGINT '$.ID'
            ) AS t1
            JOIN dbo.Document AS d
                ON t1.id = d.ID;
    END;
    --INSERT #IDList(ID)VALUES(11718144388100);
    --SET @IDList=N'11313123378850';
    IF @IDList IS NOT NULL
    BEGIN
        SELECT @BeginPeriod = MIN(ISNULL(d.AccountingDate, d.Date)),
               @EndPeriod = MAX(ISNULL(d.AccountingDate, d.Date))
        FROM dbo.Document AS d
            JOIN #IDList IDlist
                ON IDlist.ID = d.ID;
    END;
	
    DECLARE @ReconsileTypes TABLE
    (
        ID BIGINT PRIMARY KEY,
        ContractInHeader TINYINT NOT NULL
    );
    DECLARE @CommonTypesIROutgoing TABLE
    (
        id BIGINT NOT NULL,
        Opertype BIGINT NOT NULL,
        ContractInHeader TINYINT NOT NULL INDEX ID CLUSTERED (id)
    );



    --Реализации 
    DECLARE @StornoDostavkiKlientu BIGINT = 7305367777000, --OperationAgentStornoDeliveredToCustomer
            @DostavlenoKlientu BIGINT = 1031672468000;     --Доставлено клиенту	OperationAgentDeliveredToCustomer
    --@РеализацияОтгруженныхТоваровФизЛицамСторно
    DECLARE @RealizatsiyaOtgruzhennyhTovarovFizLitsamStorno BIGINT = 11178126586550; -- dbo.ObjectTypeGetBySysName('DocumentConsigOutShipmentGoodsHumanStorno');
    --@РеализацияОтгруженныхТоваровЮрЛицамСторно
    DECLARE @RealizatsiyaOtgruzhennyhTovarovYUrLitsamStorno BIGINT = 11178126586980; --dbo.ObjectTypeGetBySysName('DocumentConsigOutShipmentGoodsLegalStorno');
    --РеализацияОтгруженныхТоваровФизЛицам
    DECLARE @RealizatsiyaOtgruzhennyhTovarovFizlitsam BIGINT = 3440241986000; --Реализация отгруженных товаров физ.лицам --DocumentConsigOutShipmentGoodsHuman
    DECLARE @RealizatsiyaOtgruzhennyhTovarovFizlitsamRFBS BIGINT
        = 11213917973880,                                                          --DocumentConsigOutShipmentGoodsHumanRFBS	Реализация отгруженных товаров физ. лицам RFBS
            @RealizatsiyaOtgruzhennyhTovarovYurLitsamRFBS BIGINT = 11213917975210, --DocumentConsigOutShipmentGoodsLegalRFBS	Реализация отгруженных товаров юр. лицам RFBS
            @RealizatsiyaOtgruzhennyhTovarovYurLitsam BIGINT = 3440241988000       -- DocumentConsigOutShipmentGoodsLegal	Реализация отгруженных товаров юр.лицу
    ;
    INSERT @CommonTypesIROutgoing
    (
        id,
        Opertype,
        ContractInHeader
    )
    SELECT Doctypes.ID AS ID,
           Operttypes.ID AS OperType,
           1 AS ContractInHeader
    FROM
    (
        SELECT @DostavlenoKlientu AS ID -- OperationAgentDeliveredToCustomer Доставлено клиенту
        UNION ALL
        SELECT 11044839243620 -- Исправленная операция доставки	OperationAgentDeliveredToCustomerCanceled
    ) AS Operttypes
        CROSS JOIN
        (
            SELECT @RealizatsiyaOtgruzhennyhTovarovYurLitsam AS ID
            UNION ALL
            SELECT @RealizatsiyaOtgruzhennyhTovarovYurLitsamRFBS
            UNION ALL
            SELECT @RealizatsiyaOtgruzhennyhTovarovFizlitsamRFBS
            UNION ALL
            SELECT @RealizatsiyaOtgruzhennyhTovarovFizlitsam
        ) AS Doctypes
    -- Отгрузка товаров
    UNION ALL
    SELECT Doctypes.ID AS ID,
           Operttypes.ID AS OperType,
           1
    FROM
    (
        SELECT 33787000 AS ID -- Отправление	OperationPosting
        UNION ALL
        SELECT (885137909000) --OperationClientServicePayment 
        UNION ALL
        SELECT (766358284000) -- OperationMediaSale 
    ) AS Operttypes
        CROSS JOIN
        (
            SELECT 3440246362000 AS ID -- DocumentPostingHumanShipmentGoods	Отгрузка товаров физ. лицам
            UNION ALL
            SELECT 3440246376000 --DocumentPostingShipmentGoods	Отгрузка товаров юр. лицу
        ) AS Doctypes
    -- Прочие реализации
    UNION ALL
    SELECT 32779000,      -- DocumentPosting	Товарная накладная реализации
           5034641204000, -- Реализация со склада	WarehouseSaleOperation
           1
    UNION ALL
    SELECT 793358828000, -- DocumentConsigBackwardPurchase	Накладная выкупа товара поставщиком
           793626934000, -- Обратный выкуп	
           1
    UNION ALL
    SELECT 3440246335000, --DocumentPostingMediaContent	Накладная реализация медиаконтента
           766358284000,  -- Реализация медиаконтента	OperationMediaSale
           1
    UNION ALL
    SELECT @RealizatsiyaOtgruzhennyhTovarovFizLitsamStorno,
           @StornoDostavkiKlientu,
           1
    UNION ALL
    SELECT @RealizatsiyaOtgruzhennyhTovarovYUrLitsamStorno,
           @StornoDostavkiKlientu,
           1;

    --Возвраты
    DECLARE @VozvratOtgruzhennyhTovarovFizLitsam BIGINT
        = 3440246390000,                                                               -- DocumentItemReturnHumanShipmentGoods	Возврат отгруженных товаров физ.лицам
            @VozvratOtgruzhennyhTovarovYUrLitsam BIGINT = 3440246404000,               -- DocumentItemReturnShipmentGoods	Возврат отгруженных товаров юр.лицам
            @VozvratOtgruzhennyhTovarovFizLitsamKorrektirovka BIGINT = 11164583775990; --DocumentItemReturnCorrectionShipmentGoodsHuman	Возврат отгруженных товаров физ.лицам (корректировка)

    DECLARE @ReturnsOps TABLE
    (
        ID BIGINT NOT NULL,
        Opertype BIGINT NOT NULL,
        ContractInHeader TINYINT NOT NULL
    );
    INSERT @ReturnsOps
    (
        ID,
        Opertype,
        ContractInHeader
    )
    SELECT DocTypes.ID AS ID,
           OperTypes.ID AS OperType,
           1 AS ContractInHeader
    FROM
    (
        SELECT 11213917976050 AS ID -- Возврат RFBS	ReturnAgentOperationRFBS
        UNION ALL
        SELECT 34179000 -- Возврат ранее проданного товара	OperationItemReturn
    ) AS OperTypes
        CROSS JOIN
        (
            SELECT 3440241992000 AS ID -- DocumentItemReturnRealizationShipmentGoodsLegal	Возврат реализации отгруженных товаров юр.лицу
            UNION ALL
            SELECT 3440241990000 -- DocumentItemReturnRealizationShipmentGoodsHuman	Возврат реализации отгруженных товаров физ.лицам
            UNION ALL
            SELECT @VozvratOtgruzhennyhTovarovFizLitsam -- DocumentItemReturnHumanShipmentGoods	Возврат отгруженных товаров физ.лицам
            UNION ALL
            SELECT @VozvratOtgruzhennyhTovarovYUrLitsam -- DocumentItemReturnShipmentGoods	Возврат отгруженных товаров юр.лицам

        ) AS DocTypes
    UNION ALL
    SELECT @VozvratOtgruzhennyhTovarovFizLitsamKorrektirovka, --DocumentItemReturnCorrectionShipmentGoodsHuman	Возврат отгруженных товаров физ.лицам (корректировка)
           34179000,                                          -- Возврат ранее проданного товара	OperationItemReturn
           1
    UNION ALL
    SELECT 11213917977160, -- DocumentItemReturnRealizationHumanRFBS	Возврат реализации физ. лиц RFBS
           11213917976050, --Возврат RFBS	ReturnAgentOperationRFBS
           1
    UNION ALL
    SELECT 11213917977860, --DocumentItemReturnRealizationLegalRFBS	Возврат реализации юр. лиц RFBS
           11213917976050, --Возврат RFBS	ReturnAgentOperationRFBS
           1
    UNION ALL
    SELECT 11164583775990, --DocumentItemReturnCorrectionShipmentGoodsHuman	Возврат отгруженных товаров физ.лицам (корректировка)
           34179000,       -- Возврат ранее проданного товара	OperationItemReturn
           1
    UNION ALL
    SELECT 7731698156000, -- DocumentClientItemReturnRealizationHuman	Клиентский возврат реализации от физ лиц
           7561025591000, -- Возврат клиента	ClientReturnAgentOperation
           1
    UNION ALL
    SELECT 7731698182000, --DocumentClientItemReturnRealizationLegal	Клиентский возврат реализации от юр лица
           7561025591000, --Возврат клиента	ClientReturnAgentOperation
           1
    UNION ALL 
SELECT @VozvratOtgruzhennyhTovarovFizLitsam, 1031672468000 , 1 -- dbo.ObjectTypeGetBySysName ('OperationAgentDeliveredToCustomer')
/*UNION ALL 
SELECT @VozvratOtgruzhennyhTovarovFizLitsam, 11044839243620,1;*/
    -- dbo.ObjectTypeGetBySysName ('OperationAgentDeliveredToCustomerCanceled')
    --@ВыручкаОтДоставкиПриВозвратеОтгруженныхТоваров

    INSERT @CommonTypesIROutgoing
    (
        id,
        Opertype,
        ContractInHeader
    )
    SELECT RO.ID AS ID,
           RO.Opertype AS Opertype,
           RO.ContractInHeader AS ContractInHeader
    FROM @ReturnsOps AS RO;

    DECLARE @VyruchkaOtDostavkiPriVozvrateOtgruzhennyhTovarov BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentConsigOutDeliveryAdmission');

    --Выручка от доставки при возврате отгруженных товаров юр. лицам
    DECLARE @VyruchkaOtDostavkiPriVozvrateOtgruzhennyhTovarovYurlitsam BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentConsigOutDeliveryAdmissionLegal');

    --Возврат поставщику
    --Типы операций
    DECLARE @VozvratPostaschiku BIGINT = 410051286000; ---Возврат поставщику	OperationReturnToProvider
    DECLARE @VozvratPrihodnogoBrakaPostavschiku BIGINT = 728671605000; -- Возврат приходного брака поставщику	OperationReturnDefectiveToProvider
    DECLARE @VozvratPostaschikuKorrektirovka BIGINT = 11164583776980; --Возврат поставщику (корректировка)	OperationReturnToProviderСorrection

    --Документы
    DECLARE @NakladnayaVozvrataTovaraPostavschiku BIGINT = 30163000; --dbo.ObjectTypeGetBySysName('DocumentConsigReturnToProvider');
    --Накладная возврата излишков поставщику
    DECLARE @NakladnayaVozvrataIzlishkovPostavschiku BIGINT = 11079224437080; -- dbo.ObjectTypeGetBySysName('DocumentSurplusReturnToProvider');
    --Возврат товаров поставщику через доставку
    DECLARE @VozvratTovarovPostavschikuCherezDostavku BIGINT = 11586631037750; --dbo.ObjectTypeGetBySysName('DocumentConsigReturnToProviderOverDelivery');
    --@НакладнаяВозвратаПриходногоБракаПоставщику
    DECLARE @NakladnayaVozvrataPrihodnogoBrakaPostavschiku BIGINT = 719537915000; -- dbo.ObjectTypeGetBySysName('DocumentConsigReturnDefIncomeToProvider');
    DECLARE @OtgruzkaTovarovPostavschikuVDostavku BIGINT = 11586631036840; -- DocumentConsigReturnOverDelivery	Отгрузка возвратов поставщику в доставку
    --@НакладнаяВозвратаПоставщикуКорректировка
    DECLARE @NakladnayaVozvrataPostavschikuKorrektirovka BIGINT = 11164583776630; -- dbo.ObjectTypeGetBySysName('DocumentConsigReturnCorrectionToProvider');
    INSERT @CommonTypesIROutgoing
    (
        id,
        Opertype,
        ContractInHeader
    )
    SELECT DocTypes.ID AS ID,
           Opertypes.ID AS Opertype,
           1 AS ContractInHeader
    FROM
    (
        SELECT @NakladnayaVozvrataTovaraPostavschiku AS ID -- dbo.ObjectTypeGetBySysName('DocumentConsigReturnToProvider') @НакладнаяВозвратаТовараПоставщику
        UNION ALL
        SELECT @NakladnayaVozvrataIzlishkovPostavschiku --dbo.ObjectTypeGetBySysName('DocumentSurplusReturnToProvider') Накладная возврата излишков поставщику
        UNION ALL
        SELECT @VozvratTovarovPostavschikuCherezDostavku
        UNION ALL
        SELECT @OtgruzkaTovarovPostavschikuVDostavku -- DocumentConsigReturnOverDelivery	Отгрузка возвратов поставщику в доставку
    ) AS DocTypes
        CROSS JOIN
        (SELECT @VozvratPostaschiku AS ID) AS Opertypes
    UNION ALL
    SELECT DocTypes.ID AS ID,
           Opertypes.ID AS Opertype,
           1
    FROM
    (
        SELECT @VozvratTovarovPostavschikuCherezDostavku AS ID
        UNION ALL
        SELECT @NakladnayaVozvrataPrihodnogoBrakaPostavschiku
        UNION ALL
        SELECT @OtgruzkaTovarovPostavschikuVDostavku
    ) AS DocTypes
        CROSS JOIN
        (SELECT @VozvratPrihodnogoBrakaPostavschiku AS ID) AS Opertypes
    UNION ALL
    SELECT @NakladnayaVozvrataPostavschikuKorrektirovka,
           @VozvratPostaschikuKorrektirovka,
           1;
    --@АктНачисленияПоИнвентаризации
    DECLARE @AktNachisleniyaPoInventarizatsii BIGINT
        = 583252959000,                                                           --dbo.ObjectGetBySysName('ObjectType', 'DocumentConsigWriteOnInventory');
                                                                                  --@АктСписанияБрака
            @AktSpisaniyaBraka BIGINT = 556486648000,                             --dbo.ObjectTypeGetBySysName('DocumentConsigDefectiveWriteOff');
                                                                                  --@АктОСписанииНаПроизводственныеЦели
            @AktOSpisaniiNaProizvodstvennyyeTSeli BIGINT = 583248926000,          -- dbo.ObjectTypeGetBySysName('DocumentConsigWriteOff10');
                                                                                  --@АктОСписанииТоваров
            @AktOSpisaniiTovarov BIGINT = 556286345000,                           --dbo.ObjectTypeGetBySysName('DocumentConsigWriteOff');
                                                                                  --АктСписанияТоваровУтилизированныхВДоставке
            @AktSpisaniyaTovarovUtilizirovannyhVDostavke BIGINT = 11401472893110; --dbo.ObjectTypeGetBySysName('DocumentConsigWriteOffActForItemsUtilizedInDelivery');
    INSERT @CommonTypesIROutgoing
    (
        id,
        Opertype,
        ContractInHeader
    )
    SELECT @AktSpisaniyaBraka AS ID,
           411933456000 AS Opertype,
           0 AS ContractInHeader -- Списание брака	OperationDefectiveWriteOff
    UNION ALL
    SELECT @AktNachisleniyaPoInventarizatsii,
           634476382000,
           0 --	Начисление излишков	OperationWriteOn
    UNION ALL
    SELECT @AktOSpisaniiNaProizvodstvennyyeTSeli,
           411938495000,
           0 --	Списание на производственные цели	OperationManufacturingWriteOff
    UNION ALL
    SELECT @AktOSpisaniiTovarov,
           416508641000,
           0 --Списание недостачи	OperationLackWriteOff
    ;
    DECLARE @DohodyBuduschihPeriodov BIGINT = 11031720626870; -- dbo.ObjectTypeGetBySysName('DocumentConsigOutPremiumStatus');
    INSERT @CommonTypesIROutgoing
    (
        id,
        Opertype,
        ContractInHeader
    )
    SELECT @DohodyBuduschihPeriodov AS ID,
           11031720598470 AS Opertype, --Реализация Премиум статусов	OperationSalePremiumStatus
           0 AS ContractInHeader;



    --@MarketPlaceРеализацияЦифровыхТоваров
    DECLARE @MarketPlaceRealizatsiyaTSifrovyhTovarov BIGINT = 11270504071430; --dbo.ObjectTypeGetBySysName('DocumentRealizationReportMediaCommission');
    INSERT @CommonTypesIROutgoing
    (
        id,
        Opertype,
        ContractInHeader
    )
    VALUES
    (@MarketPlaceRealizatsiyaTSifrovyhTovarov, 11270504072460, 1 --Начисление на счет селлера Цифра	MarketplaceSellerCostOperationDigital

        );
    --Реестр начислений от селлеров на ПС
    DECLARE @ReestrNachisleniyotSellerovNaPS BIGINT = 11647867440870; -- dbo.ObjectTypeGetBySysName('DocumentSellerPartialCompensationRegister');
    INSERT @CommonTypesIROutgoing
    (
        id,
        Opertype,
        ContractInHeader
    )
    VALUES
    (@ReestrNachisleniyotSellerovNaPS, 11647867441820, 1 --	Компенсация клиентам от селлера	CompensationCustomersFromSeller

        );
    --clearing
    DECLARE @OplataZaZakaz BIGINT = 13185740000; --Оплата за заказ	OperationClientOrderPayment
    DECLARE @Fraud BIGINT = 9256766947000; --	Списание по фроду	OperationPaymentRefuseByPA
    DECLARE @PerenosDtTVR BIGINT
        = 5024287229000,                                                       -- Перенос дебиторской задолжности ТВР	OperationDebtorChange
            @VozvratPlatezhaZaZakaz BIGINT = 7301896500000,                    --Возврат платежа за заказ OperationMoneyReturn
            @NachisleniyeRMSNaPS BIGINT = 11108602832500,                      --Начисление RMS на ПС	OperationClientAccountEntryRMS
            @VyplataChayevyhKuryeru BIGINT = 11211033271240,                   --Выплата чаевых курьеру	OperationCourierTipsPayment
            @KomissiyaZaPlatezhnoyePoruchenie BIGINT = 11718725498130,         --Комиссия за платежное поручение	DocumentPaymentCourierTips	OperationCourierTipsCommissionForPayCharge
            @KomissiyaPochayevymKuryeru BIGINT = 11644218025570,               --Комиссия по чаевым курьеру	DocumentPaymentCourierTips	OperationCourierTipsCommission
            @OperationAccountClientWriteoffObjectTypeID BIGINT = 628988793000, --OperationAccountClientWriteOff     ,
            @OperatsiyaKompensatsiiSelleram BIGINT = 11211886486430;           --MarketplaceSellerCompensationOperation Marketplace Компенсации селлерам(операция)
    DECLARE @OperationPartialPaymentRepaymentId BIGINT
        = 11043972129220,                                          -- dbo.ObjectTypeGetBySysName('OperationPartialPaymentRepayment') Погашение частичной оплаты
            @OperationPartialPaymentOrder BIGINT = 11043972109380; -- OperationPartialPaymentOrder Выдача товаров с частичной оплатой
    DECLARE @OperationCertificateActivateTypeID BIGINT
        = 709875105000,                                                                     --dbo.ObjectTypeGetBySysName('OperationCertificateActivate');
            @SpisaniyeCertificata BIGINT = 709879896000,                                    -- Списание сертификата OperationCertificateWriteOf
            @PlatezhPoPrihodnomuOrderuPoKarte BIGINT = 3001495960000,                       --Платеж по приходному ордеру по карте	OperationCashInCardPay
            @ProdazhaKliyentskoyZadolzhtnnostiFactoru BIGINT = 11202238401320,              --Продажа клиентской задолженности фактору OperationClientDebtFactorSale
            @PerechisleniyekliyentskoyZadolzhennostyFactoru BIGINT = 11202238401510,        --Перечисление клиентской задолженности фактору OperationClientDebtFactorTransfer
            @PerechisleniyekliyentskoyZadolzhennostyFactoruVozvrat BIGINT = 11343858253390, --OperationClientDebtFactorTransferReturns Перечисление клиентской задолженности фактору - возвраты
            @ChastichnayaKompensatsiyaKlientu BIGINT = 11347636139880,                      --11347636139880 Частичная компенсация клиенту OperationMarketplaceServicePartialCompensationToClient
            @OperatsiyaNachisleniyeCRMNaPC BIGINT = 837163418000,                           --Начисление CRM на ПС OperationClientAccountEntryCRM
            @ProdazhaTuristicheskihUslug BIGINT = 11348237273340,                           --Продажа туристических услуг OperationRealizationTravelSales
            @MKKPerevodtretyemuLitsu BIGINT = 11347066583110,                               --MKK Перевод третьему лицу OperationMKKTransferToThirdPerson
            @KorrektirovochnayaOperatsiya BIGINT = 7908238324000,                           --Корректировочная операция OperationCorrection
            @OperatsiyaKompensatsiyaKliyentuOtTravela BIGINT = 11355367810490,              --Компенсация клиенту от Travel(операция) OperationCompensationToClientTravel
            @OtmenaOperatsiiKompensatsiyaKliyentuOtTravela BIGINT = 11355367811040,         -- dbo.ObjectTypeGetBySysName ('OperationCancelCompensationToClientTravel') - Отмена Компенсация клиенту от Travel(операция)
            @OperatsiyaKompensatsiyaSelleramZaUtrachenniyTovar BIGINT = 11576551708370,     --MarketplaceSellerCompensationLossOfGoodsOperation Marketplace Компенсация селлерам за утраченный товар(операция)
            @OplataSelleruCherezElectronniyKoshelek BIGINT = 11594730068980,                --Оплата селлеру через электронный кошелек EWalletPaymentOperation
            @OplataSelleruCherezLocalnogoPA BIGINT = 11674592655820,                        --Оплата селлеру через локального ПА PaymentOperationForLocalPaymentAgent
            @OperatsiyaTovarnayaKompensatsiyaSelleram BIGINT = 11430011603340;              --MarketplaceSellerCompensationItemOperation MarketplaceSellerCompensationItemDocument
    DECLARE @ClearingOps TABLE
    (
        ID BIGINT NOT NULL,
        OperType BIGINT NOT NULL,
        ContractInHeader TINYINT NOT NULL INDEX ID CLUSTERED (ID)
    );
    --@ОтказОтОплаты
    DECLARE @OtkazOtOplaty BIGINT = 9256766940000; -- dbo.ObjectTypeGetBySysName('DocumentInternalDebtorRefusePaymentByPA');
    --СменаДебитораПА
    DECLARE @SmenaDebitoraPA BIGINT = 5184586267000; --dbo.ObjectTypeGetBySysName('DocumentInternalDebtorChangePA');
    --СменаДебитораПАТрэвел
    DECLARE @SmenaDebitoraPATrevel BIGINT = 11333912509750; --dbo.ObjectTypeGetBySysName('DocumentInternalDebtorChangePATravel');
    --@SmenaDebitoraTVR
    DECLARE @SmenaDebitoraTVR BIGINT = 5024287229000; --Перенос дебиторской задолжности ТВР	OperationDebtorChange;
    DECLARE @SmenaDebitoraTVR_2 BIGINT = 5024287244000; --Смена дебитора ТВР	DocumentInternalDebtorChange;
    --СменаДебитораТВРПредоплата
    DECLARE @SmenaDebitoraTVRPredoplata BIGINT = 5640415560000; --dbo.ObjectTypeGetBySysName('DocumentInternalDebtorChangePrepayment');
    --ВозратПлатежейЧерезПА
    DECLARE @VozratPlatezheyCHerezPA BIGINT = 7301896520000; --dbo.ObjectTypeGetBySysName('DocumentInternalCAEMoneyReturnPA');
    --@ВыдачаСЧастичнойОплатой
    DECLARE @VydachaSCHastichnoyOplatoy BIGINT
        = 11043972141090,                                      --dbo.ObjectTypeGetBySysName('DocumentInternalPartialPayment');
            @ReestrNachisleniyRMSNaPS BIGINT = 11108602833850; --DocumentClientAccountEntryRMS Реестр начислений RMS на ПС
    --@АктивацияСертификатов
    DECLARE @AktivatsiyaSertifikatov BIGINT = 727491633000; -- dbo.ObjectTypeGetBySysName('DocumentCertificateActivation');
    --@SpisaniteCertifikatov
    DECLARE @SpisaniteCertifikatov BIGINT = 743868891000; --dbo.ObjectTypeGetBySysName('DocumentCertificateWriteOf');
    --@ПриходныйОрдер
    DECLARE @PrihodnyyOrder BIGINT = 640951471000; -- dbo.ObjectTypeGetBySysName('DocumentPayCashIn');
    --@MarketPlaceКомпенсацииСеллерам
    DECLARE @MarketPlaceKompensatsiiSelleram BIGINT = 11211886486070; --dbo.ObjectTypeGetBySysName('MarketplaceSellerCompensationDocument');
    --@ПеречислениеЧаевыхКурьеру
    DECLARE @PerechisleniyeCHayevyhKuryeru BIGINT = 11211033270790; -- dbo.ObjectTypeGetBySysName('DocumentPaymentCourierTips');
    --@СписаниеСПС
    DECLARE @SpisaniyeSPS BIGINT = 7135138397000; -- dbo.ObjectTypeGetBySysName('DocumentClientAccountEntryWriteOff');
    --@РеестрЗаказовВыданныхКлиентамВРассрочку
    DECLARE @ReyestrZakazovVydannyhKliyentamVRassrochku BIGINT = 11202238400170; --dbo.ObjectTypeGetBySysName('FactoringClientRegistry');
    --@РеестрЗаказовНаПеречислениеВБанкФакторинг
    DECLARE @ReyestrZakazovNaPerechisleniyeVBankFaktoring BIGINT = 11202238400650; -- dbo.ObjectTypeGetBySysName('FactoringBankRegistry');
    --РеестрЗаказовНаПеречислениеВБанкФакторингВозвраты
    DECLARE @ReyestrZakazovNaPerechisleniyeVBankFaktoringVozvraty BIGINT = 11343858252590; --dbo.ObjectTypeGetBySysName('FactoringBankRegistryReturns');
    --@АгентскийОтчетСеллеру
    DECLARE @AgentskiyOtchetSelleru BIGINT = 11213917985900; --dbo.ObjectTypeGetBySysName('MarketplaceDocumentAgentReportSeller');
    --@РеестрНачисленийCRMПС
    DECLARE @ReyestrNachisleniyCRMPS BIGINT = 838647894000; --dbo.ObjectTypeGetBySysName('DocumentClientAccountEntryCRM');
 --@РеализацияТрэвел
    DECLARE @RealizatsiyaTrevel BIGINT = 11348237274710; --dbo.ObjectTypeGetBySysName('DocumentRealizationTravel');
    --ТребованиеОПереводеТретьемуЛицу
    DECLARE @TrebovaniyeOPerevodeTretyemuLitsu BIGINT = 11347066589210; --dbo.ObjectTypeGetBySysName('DocumentInternalMKKRequestForTransferToThirdPerson');
    --СправкаКСменеДебитораПА
    DECLARE @SpravkaKSmeneDebitoraPA BIGINT = 11289036461110; --dbo.ObjectTypeGetBySysName('DocumentInternalDebtorChangePAReference');
    --ПереносДСсПСТрэвелНАПСОЗОН
    DECLARE @PerenosDSsPSTrevelNAPSOZON BIGINT = 11338001131200; --dbo.ObjectTypeGetBySysName('DocumentMoveCAETravelToCAEOzon');
    --КомпенсацияКлиентуОтТрэвел
    DECLARE @KompensatsiyaKliyentuOtTrevel BIGINT = 11355367813500; --dbo.ObjectTypeGetBySysName('DocumentCompensationToClientTravel');
    --Marketplace Компенсация селлерам за утраченный товар
    DECLARE @MarketplaceKompensatsiyaSelleramZaUtrachennyTovar BIGINT = 11576551705980; --dbo.ObjectTypeGetBySysName('MarketplaceSellerCompensationLossOfGoodsDocument');
    -- платеж через электронынй кошелек
    DECLARE @PlatezhCherezElectronniyKoshelek BIGINT = 11594730069810; --dbo.ObjectTypeGetBySysName('EWalletPaymentDocument');
    --Платежное поручение локальному ПА
    DECLARE @PlatezhnoyePorucheniyePoLocalnomuPA BIGINT = 11674588786030; --dbo.ObjectTypeGetBySysName('DocumentPayChargeForLocalPaymentAgent');
    --MarketPlaceТоварнаяКомпенсацияСеллерам
    DECLARE @MarketPlaceTovarnayaKompensatsiyaSelleram BIGINT = 11430011597800; --dbo.ObjectTypeGetBySysName('MarketplaceSellerCompensationItemDocument');

    
    INSERT @ClearingOps
    (
        ID,
        OperType,
        ContractInHeader
    )
    SELECT @OtkazOtOplaty AS ID,
           @Fraud AS OperType,
           1 AS ContractInHeader
    UNION ALL
    SELECT @AktSpisaniyaTovarovUtilizirovannyhVDostavke,
           11401472896140,
           1 --Списание по утилизации в доставке	OperationWriteOffByUtilizationInDelivery
    UNION ALL
    SELECT @SmenaDebitoraPA,
           @OplataZaZakaz,
           0
    UNION ALL
    SELECT @SmenaDebitoraPA,
           @OtkazOtOplaty,
           0
    UNION ALL
    SELECT @SmenaDebitoraPATrevel,
           @OplataZaZakaz,
           0
    UNION ALL
    SELECT @SmenaDebitoraPATrevel,
           @OtkazOtOplaty,
           0
    UNION ALL
    SELECT @MarketPlaceTovarnayaKompensatsiyaSelleram,
           @OperatsiyaTovarnayaKompensatsiyaSelleram,
           1
    UNION ALL
    SELECT @MarketPlaceTovarnayaKompensatsiyaSelleram,
           @OperatsiyaKompensatsiiSelleram,
           1
    UNION ALL
    SELECT @SmenaDebitoraTVR,
           @PerenosDtTVR,
           0
    UNION ALL
    SELECT @SmenaDebitoraTVR_2,
           @PerenosDtTVR,
           0
    UNION ALL
    SELECT @SmenaDebitoraTVRPredoplata,
           @PerenosDtTVR,
           0
    UNION ALL
    SELECT @VozratPlatezheyCHerezPA,
           @VozvratPlatezhaZaZakaz,
           1
    UNION ALL
    SELECT @VydachaSCHastichnoyOplatoy,
           @OperationPartialPaymentRepaymentId,
           0
    UNION ALL
    SELECT @VydachaSCHastichnoyOplatoy,
           @OperationPartialPaymentOrder,
           0
    UNION ALL
    SELECT @ReestrNachisleniyRMSNaPS,
           @NachisleniyeRMSNaPS,
           0
    UNION ALL
    SELECT @AktivatsiyaSertifikatov,
           @OperationCertificateActivateTypeID,
           0
    UNION ALL
    SELECT @SpisaniteCertifikatov,
           @SpisaniyeCertificata,
           0
    UNION ALL
    SELECT @PrihodnyyOrder,
           @PlatezhPoPrihodnomuOrderuPoKarte,
           0
    UNION ALL
    SELECT @MarketPlaceKompensatsiiSelleram,
           @OperatsiyaKompensatsiiSelleram,
           1
    UNION ALL
    SELECT @PerechisleniyeCHayevyhKuryeru,
           @VyplataChayevyhKuryeru,
           1
    UNION ALL
    SELECT @PerechisleniyeCHayevyhKuryeru,
           @KomissiyaZaPlatezhnoyePoruchenie,
           1
    UNION ALL
    SELECT @PerechisleniyeCHayevyhKuryeru,
           @KomissiyaPochayevymKuryeru,
           1
    UNION ALL
    SELECT @SpisaniyeSPS,
           @OperationAccountClientWriteoffObjectTypeID,
           0
    UNION ALL
    SELECT @ReyestrZakazovVydannyhKliyentamVRassrochku,
           @ProdazhaKliyentskoyZadolzhtnnostiFactoru,
           1
    UNION ALL
    SELECT @ReyestrZakazovNaPerechisleniyeVBankFaktoring,
           @PerechisleniyekliyentskoyZadolzhennostyFactoru,
           1
    UNION ALL
    SELECT @ReyestrZakazovNaPerechisleniyeVBankFaktoringVozvraty,
           @PerechisleniyekliyentskoyZadolzhennostyFactoruVozvrat,
           1
    /*UNION ALL
SELECT @AgentskiyOtchetSelleru, @ChastichnayaKompensatsiyaKlientu, 1*/
    UNION ALL
    SELECT @AgentskiyOtchetSelleru,
           ot.ID,
           1
    FROM dbo.ObjectType ot
    WHERE [SysName] IN ( 'MarketplaceSellerReexposureDeliveryReturnOperation',
                         'MarketplaceSellerShippingCompensationReturnOperation',
                         'OperationMarketplaceServicePartialCompensationToClient',
                         'OperationMarketplaceWithHoldingForUndeliverableGoods'
                       )
    UNION ALL
    SELECT @ReyestrNachisleniyCRMPS,
           @OperatsiyaNachisleniyeCRMNaPC,
           0
    UNION ALL
    SELECT @TrebovaniyeOPerevodeTretyemuLitsu,
           @MKKPerevodtretyemuLitsu,
           0
    UNION ALL
    SELECT @SpravkaKSmeneDebitoraPA,
           @KorrektirovochnayaOperatsiya,
           1
    UNION ALL
    SELECT @PerenosDSsPSTrevelNAPSOZON,
           @OplataZaZakaz,
           0
    UNION ALL
    SELECT @KompensatsiyaKliyentuOtTrevel,
           @OperatsiyaKompensatsiyaKliyentuOtTravela,
           1
    UNION ALL
    SELECT @KompensatsiyaKliyentuOtTrevel,
           @OtmenaOperatsiiKompensatsiyaKliyentuOtTravela,
           1
    UNION ALL
    SELECT @MarketplaceKompensatsiyaSelleramZaUtrachennyTovar,
           @OperatsiyaKompensatsiyaSelleramZaUtrachenniyTovar,
           1
    UNION ALL
    SELECT @PlatezhCherezElectronniyKoshelek,
           @OplataSelleruCherezElectronniyKoshelek,
           1
    UNION ALL
    SELECT @PlatezhnoyePorucheniyePoLocalnomuPA,
           @OplataSelleruCherezLocalnogoPA,
           1
    UNION ALL
    SELECT DocType.ID,
           OperType.ID,
           1
    FROM
    (
        SELECT @ProdazhaTuristicheskihUslug AS ID
        UNION ALL
        SELECT 11348237273500 --Возврат туристических услуг	OperationRealizationCorrectionTravelSales
        UNION ALL
        SELECT 11348237273580 --Отмена возврата туристических услуг	OperationRealizationCorrectionCancelTravelSales
        UNION ALL
        SELECT 11348237273410 --OperationRealizationCancelTravelSales Отмена продажи туристических услуг
    ) AS OperType
        CROSS JOIN
        (SELECT @RealizatsiyaTrevel AS ID) AS DocType;
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    SELECT DISTINCT
           Cl.ID AS ID,
           Cl.ContractInHeader AS ContractInHeader
    FROM @ClearingOps AS Cl;

    DECLARE @PaymentOperationsTable TABLE
    (
        operID BIGINT NOT NULL,
        opername VARCHAR(100) NOT NULL,
        opersysname VARCHAR(100) NOT NULL
    );
    INSERT @PaymentOperationsTable
    (
        operID,
        opername,
        opersysname
    )
    SELECT 11682980695430 AS OperID,
           ' Оплата по договору на услуги контента' AS opername,
           'OperationPaymentByContractAgentForSelfEmployedServices' AS opersysname
    UNION ALL
    SELECT 1965220258000,
           'Валютный контроль',
           'OperationBankComissionCurrencyControlPayment'
    UNION ALL
    SELECT 1955411493000,
           'Возврат заказа',
           'OperationBuyerReturnByItemOrder'
    UNION ALL
    SELECT 11464021297970,
           'Возврат неидентифицируемых платежей от юр.лиц',
           'OperationBuyerReturnLegalNonIdentifiedPayment'
    UNION ALL
    SELECT 432131883000,
           'Возврат ошибочной суммы',
           'OperationBackward'
    UNION ALL
    SELECT 2358124255000,
           'Возврат по договору продажи сертификатов без возврата',
           'OperationBuyerReturnByContractCertificateSaleWithoutReturn'
    UNION ALL
    SELECT 1981783676000,
           'Возврат по договору фулфилмента',
           'OperationBuyerReturnByContractStorage'
    UNION ALL
    SELECT 2022878323000,
           'Возврат реализации тур.услуг',
           'OperationBuyerReturnByContractTravelServiceSale'
    UNION ALL
    SELECT 11183478217980,
           'Выдача займа',
           'OperationdDebtGrantForApvz'
    UNION ALL
    SELECT 11595188299790,
           'Выплаты третьим лицам',
           'OperationPaymenThirdPerson'
    UNION ALL
    SELECT 11055795563660,
           'Исходящие собственные средства',
           'OperationOutgoingOwnFunds'
    UNION ALL
    SELECT 11521942819360,
           'Комиссия за платеж по аккредитиву и за гарантии',
           'OperationPaymentLCAndWarrantyCommission'
    UNION ALL
    SELECT 11007274026610,
           'Комиссия ИЛ',
           'OperationBankComissionInternetLogisticsPayment'
    UNION ALL
    SELECT 1965223940000,
           'Комиссия ИР',
           'OperationBankComissionInternetSolutionsPayment'
    UNION ALL
    SELECT 1965231037000,
           'Комиссия ИТ',
           'OperationBankComissionInternetTravel1Payment'
    UNION ALL
    SELECT 11312370519750,
           'Комиссия Озон Волга',
           'OperationBankComissionOzonVolgaPayment'
    UNION ALL
    SELECT 11449271033710,
           'Комиссия Озон Инвест',
           'OperationBankComissionOzonInvestPayment'
    UNION ALL
    SELECT 11441392409720,
           'Комиссия Озон Калининград',
           'OperationBankComissionOzonKaliningradPayment'
    UNION ALL
    SELECT 11441333405200,
           'Комиссия ОЗОН Комьюнити',
           'OperationBankComissionOzonCommunityPayment'
    UNION ALL
    SELECT 11687521361330,
           'Комиссия Озон ОРД',
           'OperationBankComissionOzonORDPayment'
    UNION ALL
    SELECT 11441389957170,
           'Комиссия Озон Поволжье',
           'OperationBankComissionOzonVolgaRegionPayment'
    UNION ALL
    SELECT 11441429422410,
           'Комиссия Озон Рокет',
           'OperationBankComissionOzonRocketPayment'
    UNION ALL
    SELECT 11042061759240,
           'Комиссия Озон Технологии',
           'OperationBankComissionOZONTechnologyPayment'
    UNION ALL
    SELECT 11441350376050,
           'Комиссия Озон Фулфилмент Сервисис',
           'OperationBankComissionOzonFulfillmentServPayment'
    UNION ALL
    SELECT 11441316000830,
           'Комиссия Озон Фулфилмент Эксплуатация',
           'OperationBankComissionOzonFulfillmentExpPayment'
    UNION ALL
    SELECT 11462701984900,
           'Комиссия Озон Холдинг',
           'OperationBankComissionOzonHoldingPayment'
    UNION ALL
    SELECT 1965225625000,
           'Комиссия ОК',
           'OperationBankComissionOCourierPayment'
    UNION ALL
    SELECT 3793513185000,
           'Комиссия ОТур',
           'OperationBankComissionOzonTurPayment'
    UNION ALL
    SELECT 1973960869000,
           'Оплата госпошлины',
           'OperationStateTax'
    UNION ALL
    SELECT 1955467043000,
           'Оплата закупки',
           'OperationSupplierPaymentByContractPurchasePostPay'
    UNION ALL
    SELECT 1982974414000,
           'Оплата закупки НМА',
           'OperationSupplierPaymentByContractPurchaseNonMatarialActive'
    UNION ALL
    SELECT 1955470884000,
           'Оплата комиссии',
           'OperationSupplierPaymentByContractCommission'
    UNION ALL
    SELECT 2090752801000,
           'Оплата НДС',
           'OperationPaymentVAT'
    UNION ALL
    SELECT 2010510692000,
           'Оплата по авторскому договору неисключительных прав с юр. лицом',
           'OperationPaymentByContractAuthorNonExclusivePersonLegal'
    UNION ALL
    SELECT 1984056551000,
           'Оплата по агентскому договору (билеты)',
           'OperationOtherContractorPaymentByContractAgentTickets'
    UNION ALL
    SELECT 1984062771000,
           'Оплата по агентскому договору (туристские услуги)',
           'OperationOtherContractorPaymentByContractTravelAgent'
    UNION ALL
    SELECT 11041642459950,
           'Оплата по агентскому договору с самозанятыми',
           'OperationOtherContractorPaymentByContractAgentForSelfEmployed'
    UNION ALL
    SELECT 1956148670000,
           'Оплата по агентскому договору со сбором ден. средств',
           'OperationOtherContractorPaymentByContractAgentDeliveryAndCash'
    UNION ALL
    SELECT 11701156341250,
           'Оплата по выкупу товара у селлера',
           'OperationSupplierPaymentForPurchaseSellerGoods'
    UNION ALL
    SELECT 1956143283000,
           'Оплата по договору на услуги по перечислению ден.средств от клиентов',
           'OperationOtherContractorPaymentByContractPaymentCollect'
    UNION ALL
    SELECT 11432329268750,
           'Оплата по договору оказания услуг по грузоперевозке',
           'PaymentUnderTheContracFoTheProvisionOfServicesForCcargoTransportation'
    UNION ALL
    SELECT 8946499119000,
           'Оплата по договору факторинга',
           'OperationSupplierPaymentByFactoringContract'
    UNION ALL
    SELECT 1956156101000,
           'Оплата по партнерскому договору с юр. лицом',
           'OperationPaymentByContractPartnerPersonLegal'
    UNION ALL
    SELECT 1956152173000,
           'Оплата по почтовому договору со сбором ден. средств',
           'OperationOtherContractorPaymentByContractPostalDeliveryAndCash'
    UNION ALL
    SELECT 8241594445000,
           'Оплата по прочим агентским договорам',
           'OperationOtherContractorPaymentByContractAgentOther'
    UNION ALL
    SELECT 3710869364000,
           'Оплата поставщику по договору комисс.обслуживания Тревел',
           'OperationSupplierPaymentByContractCommissionTravel'
    UNION ALL
    SELECT 11299151836190,
           'Оплата претензии',
           'ClaimPaymentOperation'
    UNION ALL
    SELECT 2057129801000,
           'Оплата приобретения материалов',
           'OperationSupplierPaymentByContractMaterials'
    UNION ALL
    SELECT 11347627280530,
           'Оплата прочих профессиональных услуг',
           '  PaymentForOtherProfessionalServices'
    UNION ALL
    SELECT 1955473868000,
           'Оплата реализации',
           'OperationSupplierPaymentByContractSale'
    UNION ALL
    SELECT 1955474247000,
           'Оплата страхования',
           'OperationSupplierPaymentByContractInsurance'
    UNION ALL
    SELECT 1955472847000,
           'Оплата телекоммуникационных услуг',
           'OperationSupplierPaymentByContractTelecomService'
    UNION ALL
    SELECT 1988213274000,
           'Оплата транспортных услуг',
           'OperationSupplierPaymentByContractTransport'
    UNION ALL
    SELECT 1973853843000,
           'Оплата услуг для офиса',
           'OperationOtherContractorPaymentByContractGoodsForOffice'
    UNION ALL
    SELECT 1955473100000,
           'Оплата услуг колл-центра',
           'OperationSupplierPaymentByContractCallCenterService'
    UNION ALL
    SELECT 2085726926000,
           'Оплата услуг консалтинга (юр. лицо)',
           'OperationPaymentByContractConsultingPersonLegal'
    UNION ALL
    SELECT 2463685243000,
           'Оплата услуг консалтинга в валюте (юр. лицо)',
           'OperationPaymentByContractConsultingPersonLegalInCurrency'
    UNION ALL
    SELECT 1972611566000,
           'Оплата услуг по аренде и содержанию помещений',
           'OperationSupplierPaymentByContractApartmentRent'
    UNION ALL
    SELECT 1989334334000,
           'Оплата услуг по подбору персонала',
           'OperationSupplierPaymentByContractHR'
    UNION ALL
    SELECT 2008888240000,
           'Оплата услуг по размещению рекламы',
           'OperationSupplierPaymentByContractAdvertisingPlacementService'
    UNION ALL
    SELECT 1973847756000,
           'Оплата услуг по содержанию автотранспорта',
           'OperationOtherContractorPaymentByContractMaintainingVehicle'
    UNION ALL
    SELECT 1955475382000,
           'Оплата цессии',
           'OperationSupplierPaymentByContractNoContractAssignmentPayment'
    UNION ALL
    SELECT 2037810418000,
           'Оплата штрафов',
           'OperationSupplierPaymentByContractClaimPayment'
    UNION ALL
    SELECT 11332599959900,
           'Перевод третьему лицу',
           'OperationTransferToThirdPerson'
    UNION ALL
    SELECT 2078561755000,
           'Перечисление заработной платы',
           'OperationWriteOffOtherByContractEmployeeSalary'
    UNION ALL
    SELECT 30096000,
           'Платеж',
           'OperationPayment'
    UNION ALL
    SELECT 11286558041620,
           'Платежи по таможенному счету',
           'CustomsAccountPaymentOperation'
    UNION ALL
    SELECT 2146138650000,
           'Погашение заемных обязательств (без процентов)',
           'OperationOtherContractorPaymentByContractCreditRepaymentWithoutPercent'
    UNION ALL
    SELECT 11719094725310,
           'Покупка валюты (исходящая)',
           'OperationPaymentPurchaseCurrencyEgress'
    UNION ALL
    SELECT 11601178189960,
           'Пополнение электронного кошелька',
           'OperationSupplierRefillEwallet'
    UNION ALL
    SELECT 11434500299420,
           'Поступление из банка ранее депонированной з/пл',
           'OperationOtherSupplyDepositedByContractEmployeeSalary'
    UNION ALL
    SELECT 11704655769580,
           'Поступление средств с транзитного счета',
           'OperationIncomeTransitAccount'
    UNION ALL
    SELECT 11552073597980,
           'Продажа валюты (исходящая)',
           'ConversionBargainEgress'
    UNION ALL
    SELECT 1956145646000,
           'Продажа медиаконтента',
           'OperationOtherContractorPaymentByContractServiceSaleMedia'
    UNION ALL
    SELECT 2098175915000,
           'Размещение депозита',
           'OperationDepositPlacing'
    UNION ALL
    SELECT 11289041563940,
           'Расчеты с подотчетными лицами по картам',
           'AccountablePersonsPaymentOperation'
    UNION ALL
    SELECT 2021940864000,
           'Поступление по договору на услуги по перечислению ден.средств от клиентов',
           'OperationOtherContractorSupplyByContractPaymentCollectIncoming'
    UNION ALL
    SELECT 11704652005410,
           'Списание средств с транзитного счета',
           'OperationWriteOffFundsFromTransitAccount'
    UNION ALL
    SELECT @OplataZaZakaz,
           'Оплата за заказ',
           'OperationClientOrderPayment'
    UNION ALL
    SELECT 2098271422000,
           'Возврат депозита',
           'OperationDepositReturn'
    UNION ALL
    SELECT 1972611566000,
           'Оплата услуг по аренде и содержанию помещений',
           'OperationSupplierPaymentByContractApartmentRent'
    UNION ALL
    SELECT 1973853843000,
           'Оплата услуг для офиса',
           'OperationOtherContractorPaymentByContractGoodsForOffice'
    UNION ALL
    SELECT 2028045421000,
           'Поступление по договору эквайринга',
           'OperationOtherSupplyByContractAcquiring'
    UNION ALL
    SELECT 5965807325000,
           'Поступление неидентифицируемых платежей от юр.лиц',
           'OperationClientPaymentLegalNonIdentifiedPayment';
    DECLARE @PlatezhnoyePorucheniye BIGINT = 13103174; -- dbo.ObjectTypeGetBySysName('PayCharge');
    --Зачет требований по балансу
    DECLARE @ZachetTrebovaniyPoBalansu BIGINT = dbo.ObjectTypeGetBySysName('DocumentInternalSetOffBalance');
    DECLARE @PaymentOperations TABLE
    (
        ID BIGINT NOT NULL,
        OperType BIGINT NOT NULL,
        ContractInHeader TINYINT NOT NULL INDEX ID CLUSTERED (ID)
    );
    INSERT @PaymentOperations
    (
        ID,
        OperType,
        ContractInHeader
    )
    SELECT TOP (0)
           @PlatezhnoyePorucheniye AS ID,
           POT.operID,
           0
    FROM @PaymentOperationsTable AS POT
    UNION ALL
    SELECT @ZachetTrebovaniyPoBalansu,
           11429908972030,
           0; --Операция Взаимозачета по балансу OperationSetOffBalance
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (   @PlatezhnoyePorucheniye, -- ID - bigint
        0                        -- ContractInHeader - tinyint
        );
    DECLARE @RestOps TABLE
    (
        ID BIGINT NOT NULL,
        OperType BIGINT NOT NULL,
        ContractInHeader TINYINT NOT NULL INDEX ID CLUSTERED (ID)
    );
    DECLARE @PolucheniteTovarnyhOtpravleniy BIGINT
        = 2559986248000,                                                          --Получение товарных отправлений OperationItemMoveToReceive
            @PeredachaTovarnyhOtpravleniy BIGINT = 2559986276000,                 --Передача возврата товарных отправлений OperationReturnItemMoveToSend
            @DostavkaKliyentuTovarnyhOtpravleniy BIGINT = 11397252164200,         --Доставка клиенту товарных отправлений OperationConsigItemMoveDeliveryToPrincipalClient
            @NachisleniyePoPretenzii BIGINT = 4175832484000,                      --Начисление по претензии DocumentInternalClaim
            @NachisleniyePoPretenziiNaTranzitniyeKorobki BIGINT = 11684515997500; --Начисление по претензии на транзитные коробки	DocumentInternalClaim	OperationClaimTransitBoxes
    --ПриходОтПринципала 
    DECLARE @PrihodOtPrintsipala BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigItemMoveReceiptFromPrincipal');
    --ВозвратПринципалу
    DECLARE @VozvratPrintsipalu BIGINT = 11397252162300; --dbo.ObjectTypeGetBySysName('DocumentConsigItemMoveReturnToPrincipal');
    --ДоставкаЗаказовКлиентуПринципала
    DECLARE @DostavkaZakazovKliyentuPrintsipala BIGINT = 11397252163510; --dbo.ObjectTypeGetBySysName('DocumentConsigItemMoveDeliveryToPrincipalClient');
    DECLARE @Pretenziya BIGINT = 4175626260000; --dbo.ObjectTypeGetBySysName('DocumentInternalClaim');
    INSERT @RestOps
    (
        ID,
        OperType,
        ContractInHeader
    )
    SELECT @PrihodOtPrintsipala AS ID,
           @PolucheniteTovarnyhOtpravleniy AS OperType,
           1 AS ContractInHeader
    UNION ALL
    SELECT @VozvratPrintsipalu,
           @PeredachaTovarnyhOtpravleniy,
           1
    UNION ALL
    SELECT @DostavkaZakazovKliyentuPrintsipala,
           @DostavkaKliyentuTovarnyhOtpravleniy,
           1
    UNION ALL
    SELECT @Pretenziya,
           @NachisleniyePoPretenzii,
           0
    UNION ALL
    SELECT @Pretenziya,
           @NachisleniyePoPretenziiNaTranzitniyeKorobki,
           0;
    --Отражение выручки селлера
    DECLARE @OtrazhenityVyruchkiSellera BIGINT = 11008556171890; -- dbo.ObjectTypeGetBySysName ('MarketplaceSellerGainDiversityDocument');
	    --РеализацияПополняемогоСертификата
    DECLARE @RealizatsiyaPopolnyayemogoSertifikata BIGINT = 11256877942930;-- dbo.ObjectTypeGetBySysName('DocumentPostingRechargeableCertificate');
	    --@Реализация сертификатов заказ на сайте
    DECLARE @RealizatsiyaSertifikatovFizLitsam BIGINT = 5519196553000; --dbo.ObjectTypeGetBySysName('DocumentPostingHumanCertificate');
	DECLARE @ProdazhaCertifikatov BIGINT = 5482264693000; --OperationCertificateSale
    INSERT @RestOps
    (
        ID,
        OperType,
        ContractInHeader
    )
    SELECT @OtrazhenityVyruchkiSellera,
           11699191999390,
           1 -- dbo.ObjectTypeGetBySysBame ('MarketplaceSellerCostOperationAggregate')
    UNION ALL
    SELECT @VyruchkaOtDostavkiPriVozvrateOtgruzhennyhTovarov AS ID,
           9434857288000, --Выручка от доставки	OperationSaleDeliveryAdmission
           0
    UNION ALL
    SELECT @VyruchkaOtDostavkiPriVozvrateOtgruzhennyhTovarovYurlitsam,
           11644241265840, --Выручка от доставки юр. лицам	OperationSaleDeliveryAdmissionLegal
           1
	UNION ALL
	SELECT @RealizatsiyaPopolnyayemogoSertifikata,
	@ProdazhaCertifikatov,
	0
	UNION ALL 
		SELECT @RealizatsiyaSertifikatovFizLitsam,
	@ProdazhaCertifikatov,
	0
    --VGO
    DECLARE @VozvratProdannogoTovaraVGO BIGINT
        = 11592329346190,                                            --Возврат ранее проданного товара по ВГО	OperationItemReturnIGT
            @VnutriGruppovayaZakupka BIGINT = 11619604897130,            --Внутригрупповая закупка	OperationItemIncomeIGTS
            @VnutriGruppovayaZakupkaStorno BIGINT = 11619604897230,      --	Внутригрупповая закупка (сторно)	OperationItemIncomeIGTSStorno
            @VnutriGruppovayaRealizatsiya BIGINT = 11619604897200,       --Внутригрупповая реализация	OperationSaleGTS
            @VnutriGruppovayaRealizatsiyaStorno BIGINT = 11619604897250, --Внутригрупповая реализация (сторно)	OperationSaleGTSStorno
            @DostavlenoKlientuVGO BIGINT = 11576591216610,               --Доставлено клиенту ВГО	OperationAgentDeliveredToCustomerIGT
            @StornoDostavkiKlientuVGO BIGINT = 11576591216680,           --Сторно доставки клиенту ВГО	OperationAgentStornoDeliveredToCustomerIGT
            @VozvratKlientaPoVGO BIGINT = 11592329346170;                --Возврат клиента по ВГО	ClientReturnAgentOperationIGT

    DECLARE @ZakupTovarovVGO BIGINT = 11619602845800,       --DocumentConsigPurchaseIGT	Закуп товаров ВГО
            @ZakupTovaraVGO3BC BIGINT = 11689905566670,     --DocumentConsigPurchaseIGT3BC	Закуп товаров ВГО 3BC
            @ZakupTovarovVGOStorno BIGINT = 11619602846020; --DocumentConsigPurchaseIGTStorno	Закуп товара ВГО (сторно)
    --Накладная реализации ВГО
    DECLARE @NakladnayaRealizatsiiVGO BIGINT = 11619602845880,    -- dbo.ObjectTypeGetBySysName('DocumentPostingIGT');
            @NakladnayaRealizatsiiVGO3BC BIGINT = 11689905566270; -- DocumentPostingIGT3BC	Накладная реализации ВГО 3BC
    --накладная реализации ВГО сторно
    DECLARE @NakladnayaRealizatsiiVGOStorno BIGINT = 11619602846040; --dbo.ObjectTypeGetBySysName('DocumentPostingIGTStorno');
    --Клиентский возврат реализации от физ.лиц ВГО
    DECLARE @KlientskiyVozvratRealizatsiiFizLitsVGO BIGINT
        = 11592329346040,                                                               -- dbo.ObjectTypeGetBySysName('DocumentClientItemReturnRealizationHumanIGT');
            @KlientskiyVozvratRealizatsiiYurlitsVGO BIGINT = 11592329346120,            --DocumentClientItemReturnRealizationLegalIGT	Клиентский возврат реализации от юр.лиц ВГО
            @VozvratRealizatsiiOtgruzhennyhTovarovFizLitsamVGO BIGINT = 11592329346140, --DocumentItemReturnRealizationShipmentGoodsHumanIGT	Возврат реализации отгруженных товаров физ.лицам ВГО
            @VozvratRealizatsiiOtgruzhennyhTovarovYurLitsamVGO BIGINT = 11592329346160; --DocumentItemReturnRealizationShipmentGoodsLegalIGT	Возврат реализации отгруженных товаров юр.лицам ВГО
    --Реализация отгруженных товаров физлицам ВГО
    DECLARE @RealizatsiyaOtgruzhennyhTovarovFizlitsamVGO BIGINT
        = 11576591216270,                                                               --dbo.ObjectTypeGetBySysName('DocumentConsigOutShipmentGoodsHumanIGT');
            @RealizatsiyaOtgruzhennyhTovarovYurlitsamVGO BIGINT = 11576591216410,       --DocumentConsigOutShipmentGoodsLegalIGT	Реализация отгруженных товаров юр.лицу ВГО
            @RealizatsiyaOtgruzhennyhTovarovFizlitsamStornoVGO BIGINT = 11576591216460, --DocumentConsigOutShipmentGoodsHumanStornoIGT	Реализация отгруженных товаров физ.лицам (сторно) ВГО
            @RealizatsiyaOtgruzhennyhTovarovYurlitsamStornoVGO BIGINT = 11576591216570  --DocumentConsigOutShipmentGoodsLegalStornoIGT	Реализация отгруженных товаров юр.лицу (сторно) ВГО
    ;
    DECLARE @VGOOps TABLE
    (
        ID BIGINT NOT NULL,
        OperType BIGINT NOT NULL,
        ContractInHeader TINYINT NOT NULL INDEX ID CLUSTERED (ID)
    );
    INSERT @VGOOps
    (
        ID,
        OperType,
        ContractInHeader
    )
    SELECT @ZakupTovarovVGO AS ID,
           @VnutriGruppovayaZakupka AS OperType,
           1 AS ContractInHeader
    UNION ALL
    SELECT @ZakupTovaraVGO3BC,
           @VnutriGruppovayaZakupka,
           1
    UNION ALL
    SELECT @ZakupTovarovVGOStorno,
           @VnutriGruppovayaZakupkaStorno,
           1
    UNION ALL
    SELECT @NakladnayaRealizatsiiVGO,
           @VnutriGruppovayaRealizatsiya,
           1
    UNION ALL
    SELECT @NakladnayaRealizatsiiVGO3BC,
           @VnutriGruppovayaRealizatsiya,
           1
    UNION ALL
    SELECT @NakladnayaRealizatsiiVGOStorno,
           @VnutriGruppovayaRealizatsiyaStorno,
           1
    UNION ALL
    SELECT @KlientskiyVozvratRealizatsiiFizLitsVGO,
           @VozvratKlientaPoVGO,
           1
    UNION ALL
    SELECT @KlientskiyVozvratRealizatsiiYurlitsVGO,
           @VozvratKlientaPoVGO,
           1
    UNION ALL
    SELECT @VozvratRealizatsiiOtgruzhennyhTovarovFizLitsamVGO,
           @VozvratProdannogoTovaraVGO,
           1
    UNION ALL
    SELECT @VozvratRealizatsiiOtgruzhennyhTovarovYurLitsamVGO,
           @VozvratProdannogoTovaraVGO,
           1
    UNION ALL
    SELECT @RealizatsiyaOtgruzhennyhTovarovFizlitsamVGO,
           @DostavlenoKlientuVGO,
           1
    UNION ALL
    SELECT @RealizatsiyaOtgruzhennyhTovarovYurlitsamVGO,
           @DostavlenoKlientuVGO,
           1
    UNION ALL
    SELECT @RealizatsiyaOtgruzhennyhTovarovFizlitsamStornoVGO,
           @StornoDostavkiKlientuVGO,
           1
    UNION ALL
    SELECT @RealizatsiyaOtgruzhennyhTovarovYurlitsamStornoVGO,
           @StornoDostavkiKlientuVGO,
           1;

    INSERT @CommonTypesIROutgoing
    (
        id,
        Opertype,
        ContractInHeader
    )
    SELECT VGO.ID AS ID,
           VGO.OperType AS Opertype,
           VGO.ContractInHeader AS ContractInHeader
    FROM @VGOOps AS VGO;


    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    SELECT C.id AS ID,
           C.ContractInHeader AS ContractInHeader
    FROM @CommonTypesIROutgoing AS C
    UNION
    SELECT R.ID AS ID,
           R.ContractInHeader AS ContractInHeader
    FROM @RestOps AS R
    UNION
    SELECT PO.ID AS ID,
           PO.ContractInHeader AS ContractInHeader
    FROM @PaymentOperations AS PO;
    --@КредитНота
    DECLARE @CreditNote BIGINT = dbo.ObjectTypeGetBySysName('CreditNote');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@CreditNote, 1);
    DECLARE @AktVypolnennyhRabotSelleraIskhodyashchij BIGINT
        = dbo.ObjectTypeGetBySysName('MarketplaceDocumentExecutionJobAct');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotSelleraIskhodyashchij, 1); --@АктВыполненныхРаботИсходящий


    DECLARE @AktVypolnennyhRabotIskhodyashchij BIGINT = dbo.ObjectTypeGetBySysName('DocumentExecutionJobActOut');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotIskhodyashchij, 1);

    --@АктНедостачиИмпорта
    DECLARE @AktNedostachiImporta BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigClaimShortcomingImport');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktNedostachiImporta, 1);


    DECLARE @CommonTypesIrInGoing TABLE
    (
        ID BIGINT PRIMARY KEY
    );
    INSERT @CommonTypesIrInGoing
    SELECT ID AS ID
    FROM dbo.ObjectType
    WHERE SysName IN ( 'DocumentConsigPurchase', 'DocumentConsigCommission', 'DocumentConsigRealization' );
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    SELECT ID AS ID,
           1 AS ContractInHeader
    FROM @CommonTypesIrInGoing;
    --@AktVypolnennyhRabotPartnera
    DECLARE @AktVypolnennyhRabotPartnera BIGINT = dbo.ObjectTypeGetBySysName('DocumentExecutionJobActPartner');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotPartnera, 1);
    --@Инвойс
    DECLARE @Invoys BIGINT = dbo.ObjectTypeGetBySysName('ImportInvoiceDocument');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@Invoys, 1);

    --@AktVypolnennyhRabotAgentapoDostavkeВходящий
    DECLARE @AktVypolnennyhRabotAgentaPoDostavkeVhodyaschiy BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentExecutionJobActSubAgent');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotAgentaPoDostavkeVhodyaschiy, 1);
    INSERT @CommonTypesIrInGoing
    (
        ID
    )
    VALUES
    (@AktVypolnennyhRabotAgentaPoDostavkeVhodyaschiy -- ID - bigint
        );
    --@АктВыполненныхРаботПоАрендеВходящий
    DECLARE @AktVypolnennyhRabotPoArendeVhodyaschiy BIGINT = dbo.ObjectTypeGetBySysName('DocumentExecutionJobActRent');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotPoArendeVhodyaschiy, 1);


 --@озОтчетОбНДССАвансовФизЛиц
    DECLARE  @HumanAdvanceVATReport BIGINT = dbo.ObjectTypeGetBySysName('HumanAdvanceVATReport');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@HumanAdvanceVATReport, 1);


    --@АктВыполненныхРаботПоРекламе
    DECLARE @AktVypolnennyhRabotPoReklame BIGINT = dbo.ObjectTypeGetBySysName('AdvertisementDocumentExecutionJobAct');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotPoReklame, 1);
    --@АктПриемкиПередачи
    DECLARE @AktPriyemkiPeredachi BIGINT = dbo.ObjectTypeGetBySysName('DocumentExecutionJobActAcceptance');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktPriyemkiPeredachi, 1);
    --@АктПриемкиПередачиПредварительно
    DECLARE @AktPriyemkiPeredachiPredvaritelno BIGINT = dbo.ObjectTypeGetBySysName('DocumentExecutionJobAccruals');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktPriyemkiPeredachiPredvaritelno, 1);
    --@НачислениеПартнерскогоВознаграждения
    DECLARE @NachisleniyePartnerskogoVoznagrazhdeniya BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentInternalCostsPartner');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@NachisleniyePartnerskogoVoznagrazhdeniya, 1);
    --@АктВыполненныхРаботАгентапоДоставке
    DECLARE @AktVypolnennyhRabotAgentapoDostavke BIGINT = dbo.ObjectTypeGetBySysName('DocumentExecutionJobActAgent');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotAgentapoDostavke, 1);
    --@НакладнаяНаХранение
    DECLARE @NakladnayaNaHraneniye BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigIncomeStorage');
    INSERT @CommonTypesIrInGoing
    VALUES
    (@NakladnayaNaHraneniye);
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@NakladnayaNaHraneniye, 1);
    --@НакладнаяНаРеализацию
    DECLARE @NakladnayaNaRealizatsiyu BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigRealization');


    --@КомиссионноеВознаграждение
    DECLARE @KomissionnoyeVoznagrazhdeniye BIGINT = dbo.ObjectTypeGetBySysName('DocumentRealizationReportCommission');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@KomissionnoyeVoznagrazhdeniye, 1);
    --@КомиссионноеВознаграждениеТрэвел
    DECLARE @KomissionnoyeVoznagrazhdeniyeTrevel BIGINT = dbo.ObjectTypeGetBySysName('DocumentCommissionTravel');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@KomissionnoyeVoznagrazhdeniyeTrevel, 1);
    --@АктВыполненныхРаботПоИнвойсу
    DECLARE @AktVypolnennyhRabotPoInvoysu BIGINT = dbo.ObjectTypeGetBySysName('DocumentInvoiceExecutionJobAct');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotPoInvoysu, 1);
    --@ГТД
    DECLARE @GTD BIGINT = dbo.ObjectTypeGetBySysName('CustomsDeclarationDocument');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@GTD, 1);
    --@ОтражениеВручкиСубагента
    DECLARE @OtrazheniyeVruchkiSubagenta BIGINT = dbo.ObjectTypeGetBySysName('DocumentGainDiversitySubAgent');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@OtrazheniyeVruchkiSubagenta, 0);

    --@АктПередачиСертификатов
    DECLARE @AktPeredachiSertifikatov BIGINT = dbo.ObjectTypeGetBySysName('DocumentCertificateTransferAct');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktPeredachiSertifikatov, 1);
    --@АктивацияСертификатовПластик
    DECLARE @AktPeredachiSertifikatovPlastik BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentPlasticCertificateTransferAct');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktPeredachiSertifikatovPlastik, 1);

    --@АктПоРетроБонусам
    DECLARE @AktPoRetroBonusam BIGINT = dbo.ObjectTypeGetBySysName('DocumentRetroBonusAct');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktPoRetroBonusam, 1);
    --АктПоРетроБонусамПредварительно
    DECLARE @AktPoRetroBonusamPredvaritelno BIGINT = dbo.ObjectTypeGetBySysName('DocumentRetroBonusActForecast');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktPoRetroBonusamPredvaritelno, 1);
    --@АктОБраке
    DECLARE @AktOBrake BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigClaimDefective');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktOBrake, 1);
    --@АктОНедостачи
    DECLARE @AktONedostachi BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigClaimShortcoming');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktONedostachi, 1);
    --@АктОБракеВес
    DECLARE @AktOBrakeVes BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigClaimDefectiveWeight');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktOBrakeVes, 1);
    --@АктОНедостачеВес
    DECLARE @AktONedostacheVes BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigClaimShortcomingWeight');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktONedostacheVes, 1);
    --@MarketPlaceКорректировкаСуммКомиссионныхТоваров
    DECLARE @MarketPlaceKorrektirovkaSummKomissionnyhTovarov BIGINT
        = dbo.ObjectTypeGetBySysName('MarketplaceSellerCorrectionDocumentForProductCommission');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@MarketPlaceKorrektirovkaSummKomissionnyhTovarov, 1);
    --MarketPlaceКорректировкаCуммУслуг
    DECLARE @MarketPlaceKorrektirovkaSummUslug BIGINT
        = dbo.ObjectTypeGetBySysName('MarketplaceSellerCorrectionDocumentForService');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@MarketPlaceKorrektirovkaSummUslug, 1);
    --@ДооприходованиеПоПриходнойНакладной
    DECLARE @DooprihodovaniyePoPrihodnoyNakladnoy BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentConsigIncomeInboundAfterCloseByIncomeConsig');
    INSERT @CommonTypesIrInGoing
    (
        ID
    )
    VALUES
    (@DooprihodovaniyePoPrihodnoyNakladnoy);
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@DooprihodovaniyePoPrihodnoyNakladnoy, 0);
    DECLARE @FBSCrossBorder BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigFBSCrossborder');

    IF @BeginPeriod < '20230801'
       OR @IDList IS NOT NULL
    BEGIN
        INSERT @CommonTypesIrInGoing
        (
            ID
        )
        VALUES
        (@FBSCrossBorder);
        INSERT @ReconsileTypes
        (
            ID,
            ContractInHeader
        )
        VALUES
        (@FBSCrossBorder, 1);
    END;
    --@SmenaTVRAgenta
    DECLARE @SmenaTVRAgenta BIGINT = dbo.ObjectTypeGetBySysName('DocumentInternalDebtorChangeAgent');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@SmenaTVRAgenta, 0);
    --@НачисленияНаПС
    DECLARE @NachisleniyaNaPS BIGINT = dbo.ObjectTypeGetBySysName('DocumentClientAccountEntryWriteIn');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@NachisleniyaNaPS, 0);

    --ВозвратПлатежейЧерезБанк
    DECLARE @VozvratPlatezheyCHerezBank BIGINT = dbo.ObjectTypeGetBySysName('DocumentInternalCAEMoneyReturnBank');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@VozvratPlatezheyCHerezBank, 0);

    --@VozvratPlatezheyCHerezPochtu
    DECLARE @VozvratPlatezheyCHerezPochtu BIGINT = dbo.ObjectTypeGetBySysName('DocumentInternalCAEMailReturn');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@VozvratPlatezheyCHerezPochtu, 0);
    --@ЗачетТребований
    DECLARE @ZachetTrebovaniy BIGINT = dbo.ObjectTypeGetBySysName('DocumentInternalSetOff');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@ZachetTrebovaniy, 1);

    --@ШтрафнаяСанкция
    DECLARE @SHtrafnayaSanktsiya BIGINT = dbo.ObjectTypeGetBySysName('DocumentPenaltyClause');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@SHtrafnayaSanktsiya, 0);
    --@ФактическаяОплатаСеллеров
    DECLARE @FakticheskayaOplataSellerov BIGINT = dbo.ObjectTypeGetBySysName('DocumentSellerPaymentActual');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@FakticheskayaOplataSellerov, 0);

    --НакладнаяЗакупки
    DECLARE @NakladnayaZakupki BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigPurchase');
    --НакладнаяНаКомиссию
    DECLARE @NakladnayaNaKomissiyu BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigCommission');
    --Выкуп товара у селлера
    DECLARE @VykupTovaraUSellera BIGINT = dbo.ObjectTypeGetBySysName('DocumentPurchaseSellerGoods');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (   @VykupTovaraUSellera, -- ID - bigint
        1                     -- ContractInHeader - tinyint
        );
    INSERT @CommonTypesIrInGoing
    (
        ID
    )
    VALUES
    (@VykupTovaraUSellera -- ID - bigint
        );
		--Выкуп товара у селлера (неотфактуровка)
DECLARE @VykupTovaraUSelleraNeotFacturovano BIGINT = 11733849633010; -- DocumentPurchaseSellerGoodsInvoicing 
INSERT @CommonTypesIrInGoing
(
    ID
)
VALUES
(@VykupTovaraUSelleraNeotFacturovano
    );
INSERT @ReconsileTypes
(
    ID,
    ContractInHeader
)
VALUES
(   @VykupTovaraUSelleraNeotFacturovano,
    1
    );
    --РеестрТранзакцийКПлатежномуПоручениюОтПАОнлайнЭквайринг
    DECLARE @ReyestrTranzaktsiyKPlatezhnomuPorucheniyuOtPAOnlaynEkvayring BIGINT
        = dbo.ObjectTypeGetBySysName('PaychargePATransactionRegistry');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@ReyestrTranzaktsiyKPlatezhnomuPorucheniyuOtPAOnlaynEkvayring, 1);
    --СправкаКПрочимСписаниямДенегЭквайринг
    DECLARE @SpravkaKProchimSpisaniyamDenegEkvayring BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentOtherPaymentOffReferenceAcquiring');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@SpravkaKProchimSpisaniyamDenegEkvayring, 0);
    --ПриходИзПроизводства
    DECLARE @PrihodIzProizvodstva BIGINT = dbo.ObjectTypeGetBySysName('DocumentConsigWithProduction');
    INSERT @CommonTypesIrInGoing
    (
        ID
    )
    VALUES
    (@PrihodIzProizvodstva);
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@PrihodIzProizvodstva, 0);
    --Фактическаяоплатаселлеровсторно
    DECLARE @FakticheskayaOplataSellerovStorno BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentSellerPaymentActualStorno');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@FakticheskayaOplataSellerovStorno, 0);

    --ФактическаяОплатаПоставщиков
    DECLARE @FakticheskayaOplataPostavschikov BIGINT = dbo.ObjectTypeGetBySysName('DocumentSupplierPaymentActual');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@FakticheskayaOplataPostavschikov, 0);
    --РеестрОплатПоставщику
    DECLARE @ReyestrOplatPostavschiku BIGINT = dbo.ObjectTypeGetBySysName('DocumentSupplierPaymentRegister');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@ReyestrOplatPostavschiku, 0);
    --АктПриемаТоваров
    DECLARE @AktPriyemaTovarov BIGINT = dbo.ObjectTypeGetBySysName('ActOfAcceptanceOfGoods');
    INSERT @CommonTypesIrInGoing
    (
        ID
    )
    VALUES
    (@AktPriyemaTovarov);
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@AktPriyemaTovarov, 1);
    --ШтрафнаяСанкцияТоварная
    DECLARE @SHtrafnayaSanktsiyaTovarnaya BIGINT = dbo.ObjectTypeGetBySysName('DocumentPenaltyClauseItems');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@SHtrafnayaSanktsiyaTovarnaya, 1);
    --MarketPlaceПеревыставлениеУслугДоставки
    DECLARE @MarketPlacePerevystavleniyeUslugDostavki BIGINT
        = dbo.ObjectTypeGetBySysName('MarketplaceRedistributionOfDeliveryServices');
    INSERT @CommonTypesIrInGoing
    (
        ID
    )
    VALUES
    (@MarketPlacePerevystavleniyeUslugDostavki);
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@MarketPlacePerevystavleniyeUslugDostavki, 1);
    --актВыполненныхРаботаАгентапоДоставкеВходящийСторно
    DECLARE @aktVypolnennyhRabotaAgentapoDostavkeVhodyaschiyStorno BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentExecutionJobActSubAgentStorno');
    INSERT @CommonTypesIrInGoing
    (
        ID
    )
    VALUES
    (@aktVypolnennyhRabotaAgentapoDostavkeVhodyaschiyStorno);
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@aktVypolnennyhRabotaAgentapoDostavkeVhodyaschiyStorno, 1);
    --Распределение неидентифицируемого платежа на заказ
    DECLARE @RaspredelenieNeidentifitsirovannogoPlatejaNaZakaz BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentDistributionNonIdentifiedPaymentOrder');

    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@RaspredelenieNeidentifitsirovannogoPlatejaNaZakaz, 0);
    --Передача на ответственное хранение ВГО
    DECLARE @PerdachaNaOtvetHraneniyeVGO BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentTransferToResponsibleStorageIGT');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@PerdachaNaOtvetHraneniyeVGO, 1);
    --Акт выполненных работ по рекламе (Рекламный кабинет поставщика)
    DECLARE @AktVypolnennyhRabotPoReklameReklamnyKabinetPostavschika BIGINT
        = dbo.ObjectTypeGetBySysName('AdvertisementDocumentExecutionJobActAdvCabinet');
    INSERT @ReconsileTypes
    (
        ID,
      ContractInHeader
    )
    VALUES
    (@AktVypolnennyhRabotPoReklameReklamnyKabinetPostavschika, 1);
    --Перевыставляемые услуги доставки
    DECLARE @PerevystavlyaemyeUslugiDostavki BIGINT
        = dbo.ObjectTypeGetBySysName('MarketplaceRedistributedDeliveryServices');
    INSERT @CommonTypesIrInGoing
    (
        ID
    )
    VALUES
    (@PerevystavlyaemyeUslugiDostavki);
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@PerevystavlyaemyeUslugiDostavki, 1);
    --Перевыставление услуг СМЗ
    DECLARE @PerevystavleniyeUslugSMZ BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentCostTransferForSelfEmployedServices');

    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@PerevystavleniyeUslugSMZ, 1);
    DECLARE @PriemNaOtvetHraneniyeVGO BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentAcceptance1PToResponsibleStorageIGT');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@PriemNaOtvetHraneniyeVGO, 1);
    --Marketplace Вознаграждение селлера за объем продаж(Аккруал)
    DECLARE @MarketPlaceVoznagrazhdenieSelleraZaObyemProdazhAccruals BIGINT
        = dbo.ObjectTypeGetBySysName('DocumentMarketplaceSellerRewardForSalesAccrualVolume');
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@MarketPlaceVoznagrazhdenieSelleraZaObyemProdazhAccruals, 1);
    --Marketplace Вознаграждение селлера за объем продаж
    DECLARE @MarketPlaceVoznagrazhdenieSelleraZaObyemProdazh BIGINT = 11691503645310; --DocumentMarketplaceSellerRewardForSalesVolume Marketplace Вознаграждение селлера за объем продаж
    INSERT @ReconsileTypes
    (
        ID,
        ContractInHeader
    )
    VALUES
    (@MarketPlaceVoznagrazhdenieSelleraZaObyemProdazh, 1);

	--Палетная приемка
	DECLARE @PaletnayaPriemka BIGINT = 11672271629350; --DocumentPalletAcceptance 
	INSERT @ReconsileTypes
	(
	    ID,
	    ContractInHeader
	)
	VALUES
	(   @PaletnayaPriemka, -- ID - bigint
	    1  -- ContractInHeader - tinyint
	    );
--передача пп на ответ хранение
DECLARE @PeredachaPPnaOtvetHraneniyeVGO BIGINT = 11672271630830; --DocumentTransfer1PToResponsibleStorageIGT
	INSERT @ReconsileTypes
	(
	    ID,
	    ContractInHeader
	)
	VALUES
	(   @PeredachaPPnaOtvetHraneniyeVGO, -- ID - bigint
	    0  -- ContractInHeader - tinyint
	    );

    DECLARE @OperTypes dbo.IDTable;
    INSERT @OperTypes
    (
        ID
    )
    SELECT DISTINCT
           CTO.Opertype AS ID
    FROM @CommonTypesIROutgoing AS CTO;
    DROP TABLE IF EXISTS #CommonTypesIROutgoing;
    CREATE TABLE #CommonTypesIROutgoing
    (
        ID BIGINT NOT NULL INDEX ID CLUSTERED (ID),
        OperType BIGINT NOT NULL,
        pNum INT NOT NULL
    );
    INSERT #CommonTypesIROutgoing
    (
        ID,
        OperType,
        pNum
    )
    SELECT DISTINCT
           CTO.id AS ID,
           CTO.Opertype,
           opnum.pnum
    FROM @CommonTypesIROutgoing AS CTO
        LEFT JOIN dbo.pNumByOperationObjectTypeLst(
                                                      @OperTypes,
                                                      DATEADD(MONTH, -1, @BeginPeriod),
                                                      DATEADD(MONTH, 1, @EndPeriod)
                                                  ) AS opnum
            ON opnum.ObjectTypeID = CTO.Opertype
        JOIN dbo.ObjectType ot
            ON ot.ID = CTO.id;

    DELETE FROM @OperTypes;
    INSERT @OperTypes
    (
        ID
    )
    SELECT CO.OperType AS ID
    FROM @ClearingOps AS CO
    UNION
    SELECT RO.OperType AS ID
    FROM @RestOps AS RO
    UNION
    SELECT PO.OperType
    FROM @PaymentOperations AS PO;

    DROP TABLE IF EXISTS #OperTypes;
    CREATE TABLE #OperTypes
    (
        id BIGINT NOT NULL INDEX ID CLUSTERED (id),
        OperType BIGINT NULL,
        pNum SMALLINT NOT NULL,
        Clearing TINYINT NOT NULL,
        RestOps TINYINT NOT NULL,
        Payments TINYINT NOT NULL
    );
    INSERT #OperTypes
    (
        id,
        OperType,
        pNum,
        Clearing,
        RestOps,
        Payments
    )
    SELECT Clearing.ID AS ID,
           Clearing.OperType AS Opertype,
           opnum.pnum,
           1 AS Clearing,
           0 AS RestOps,
           0 AS Payments
    FROM @ClearingOps AS Clearing
        JOIN dbo.pNumByOperationObjectTypeLst(
                           @OperTypes,
                                                 DATEADD(MONTH, -1, @BeginPeriod),
                                                 DATEADD(MONTH, 1, @EndPeriod)
                                             ) AS opnum
            ON opnum.ObjectTypeID = Clearing.OperType
    UNION
    SELECT RestOps.ID AS ID,
           RestOps.OperType AS Opertype,
           opnum.pnum,
           0,
           1,
           0
    FROM @RestOps AS RestOps
        JOIN dbo.pNumByOperationObjectTypeLst(
                                                 @OperTypes,
                                                 DATEADD(MONTH, -1, @BeginPeriod),
                                                 DATEADD(MONTH, 1, @EndPeriod)
                                             ) AS opnum
            ON opnum.ObjectTypeID = RestOps.OperType
    UNION
    SELECT PO.ID AS ID,
           PO.OperType AS Opertype,
           opnum.pnum,
           0,
           0,
           1
    FROM @PaymentOperations AS PO
        JOIN dbo.pNumByOperationObjectTypeLst(
                                                 @OperTypes,
                                                 DATEADD(MONTH, -1, @BeginPeriod),
                                                 DATEADD(MONTH, 1, @EndPeriod)
                                             ) AS opnum
            ON opnum.ObjectTypeID = PO.OperType
    UNION
    SELECT CTO.ID,
           CTO.OperType,
           CTO.pNum,
           0,
           0,
           0
    FROM #CommonTypesIROutgoing AS CTO;

    DROP TABLE IF EXISTS #CommonTYPESIRIngoing;
    CREATE TABLE #CommonTYPESIRIngoing
    (
        ID BIGINT NOT NULL INDEX ID UNIQUE CLUSTERED (ID)
    );
    INSERT #CommonTYPESIRIngoing
    (
        ID
    )
    SELECT ID AS ID
    FROM @CommonTypesIrInGoing;

    DROP TABLE IF EXISTS #NoCostingTypes;
    CREATE TABLE #NoCostingTypes
    (
        ID BIGINT NOT NULL INDEX ID UNIQUE CLUSTERED (ID)
    );
    INSERT #NoCostingTypes
    (
        ID
    )
    SELECT @AktOSpisaniiNaProizvodstvennyyeTSeli AS ID
    UNION ALL
    SELECT @AktSpisaniyaBraka
    UNION ALL
    SELECT @AktNachisleniyaPoInventarizatsii
    UNION ALL
    SELECT @NakladnayaVozvrataIzlishkovPostavschiku
    UNION ALL
    SELECT @VozvratTovarovPostavschikuCherezDostavku
    UNION ALL
    SELECT @AktVypolnennyhRabotSelleraIskhodyashchij
    UNION ALL
    SELECT @AktVypolnennyhRabotPoReklameReklamnyKabinetPostavschika;
    DROP TABLE IF EXISTS #ClearingRO;
    CREATE TABLE #ClearingRO
    (
        ID BIGINT PRIMARY KEY
    );
    INSERT #ClearingRO
    (
        ID
    )
    SELECT Cl.ID
    FROM @ClearingOps AS Cl
    UNION
    SELECT RO.ID
    FROM @RestOps AS RO;

    DROP TABLE IF EXISTS #ReconsileTypes;
    CREATE TABLE #ReconsileTypes
    (
        ID BIGINT NOT NULL INDEX ID UNIQUE CLUSTERED (ID),
        CommonIrIngoing TINYINT NOT NULL,
        CommonIROutGoing TINYINT NOT NULL,
        NoCosting TINYINT NOT NULL,
        ContractInHeader TINYINT NOT NULL,
        Clearing TINYINT NOT NULL,
        RestOps TINYINT NOT NULL,
		ISVGO TINYINT NOT NULL INDEX ContractInHeader NONCLUSTERED (ContractInHeader)
    );
    INSERT #ReconsileTypes
    (
        ID,
        CommonIrIngoing,
        CommonIROutGoing,
        NoCosting,
        ContractInHeader,
        Clearing,
        RestOps,
		IsVGO
    )
    SELECT DISTINCT
           R.ID AS ID,
           CASE
               WHEN Cit.ID IS NULL THEN
                   0
               ELSE
                   1
           END AS CommonIROutGoing,
           CASE
               WHEN CtO.ID IS NULL THEN
                   0
               ELSE
                   1
           END AS CommonIROutGoing,
           CASE
               WHEN NCT.ID IS NULL THEN
                   0
               ELSE
                   1
           END AS NoCosting,
           R.ContractInHeader AS ContractInHeader,
           CASE
               WHEN CO.ID IS NULL THEN
                   0
               ELSE
                   1
           END AS Clearing,
           CASE
               WHEN RO.ID IS NULL THEN
                   0
               ELSE
                   1
           END AS RestOps,
		   CASE WHEN VGO.ID IS NULL THEN 0 ELSE 1 END AS IsVGO
    FROM @ReconsileTypes R
        LEFT JOIN #CommonTYPESIRIngoing Cit
            ON Cit.ID = R.ID
        LEFT JOIN #CommonTypesIROutgoing AS CtO
            ON CtO.ID = R.ID
        LEFT JOIN #NoCostingTypes AS NCT
            ON NCT.ID = R.ID
        LEFT JOIN @ClearingOps AS CO
            ON CO.ID = R.ID
        LEFT JOIN @RestOps AS RO
            ON RO.ID = R.ID
			LEFT JOIN @VGOOps AS VGO
			ON VGO.ID = R.ID;

            
    DECLARE @Updated DATETIME = GETDATE();
    DECLARE @ContractPurchase BIGINT = dbo.ObjectTypeGetBySysName('ContractPurchase');
    DECLARE @ContractCommission BIGINT = dbo.ObjectTypeGetBySysName('ContractCommission');
    DECLARE @ContractStorage BIGINT = dbo.ObjectTypeGetBySysName('ContractStorage');
    DECLARE @ContractPurchasePostPay BIGINT = dbo.ObjectTypeGetBySysName('ContractPurchasePostPay');
    --SET STATISTICS XML ON;
    --Платежные поручения получаем из дат банк операций  
    --При этом если отбор происходит не по периоду, то такое получение нам не надо, так как получим документ по ID  

    DROP TABLE IF EXISTS #BankOperations;
    CREATE TABLE #BankOperations
    (
        AccountingDate DATETIME NULL,
        DocumentID BIGINT NOT NULL INDEX DocumentID CLUSTERED (DocumentID)
    );
    INSERT #BankOperations
    (
        AccountingDate,
        DocumentID
    )
    SELECT bo.AccountingDate AS AccountingDate,
           bo.DocumentID AS DocumentID
    FROM dbo.BankOperation AS bo
    WHERE bo.AccountingDate
          BETWEEN @BeginPeriod AND @EndPeriod
          AND @IDList IS NULL
          AND bo.DocumentID IS NOT NULL
    UNION
    SELECT bo.AccountingDate AS AccountingDate,
           bo.DocumentID
    FROM dbo.BankOperation AS bo
        JOIN #IDList AS idlist
            ON idlist.ID = bo.DocumentID
			AND @IDList IS not NULL
    OPTION (MAXDOP 8);
    BEGIN
        IF @TurnMetrics > 0
            SELECT '#BankOperations',
                   DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    --получение документов оснований
    DROP TABLE IF EXISTS #ParentDocTypes;
    CREATE TABLE #ParentDocTypes
    (
        ID BIGINT NOT NULL INDEX ID UNIQUE CLUSTERED
    );
    INSERT #ParentDocTypes
    (
        ID
    )
    SELECT R.ID AS ID
    FROM #ReconsileTypes AS R
    WHERE R.ID IN ( @CreditNote, @AktPriyemkiPeredachi, @AktPriyemkiPeredachiPredvaritelno,
                    @aktVypolnennyhRabotaAgentapoDostavkeVhodyaschiyStorno, @KomissionnoyeVoznagrazhdeniye,
                    @NakladnayaVozvrataPostavschikuKorrektirovka
                  )
    UNION
    SELECT CTI.ID
    FROM #CommonTYPESIRIngoing AS CTI;

    DROP TABLE IF EXISTS #BillingDocs;
    CREATE TABLE #BillingDocs
    (
        ID BIGINT NOT NULL
    );
    INSERT #BillingDocs
    (
        ID
    )
    SELECT d.ID AS ID
    FROM dbo.Document AS d
    WHERE d.ObjectTypeId = @KomissionnoyeVoznagrazhdeniye
          AND d.AccountingDate
          BETWEEN @BeginPeriod AND @EndPeriod
          AND @IDList IS NULL
    UNION ALL
    SELECT d.ID
    FROM dbo.Document AS d
        JOIN #IDList AS IL
            ON IL.ID = d.ID
    WHERE d.ObjectTypeId = @KomissionnoyeVoznagrazhdeniye
          AND @IDList IS NOT NULL;

    DROP TABLE IF EXISTS #ParentDocKeys;

    CREATE TABLE #ParentDocKeys
    (
        OriginalDoc BIGINT NOT NULL,
        OriginalDocType BIGINT NOT NULL INDEX OriginalDoc CLUSTERED
    );
    INSERT #ParentDocKeys
    (
        OriginalDoc,
        OriginalDocType
    )
    SELECT d.ID AS OriginalDoc,
           d.ObjectTypeId AS OriginalDocType
    FROM dbo.Document d
        JOIN #ParentDocTypes AS PDT
            ON PDT.ID = d.ObjectTypeId
               AND d.AccountingDate
               BETWEEN @BeginPeriod AND @EndPeriod
    WHERE @IDList IS NULL
    UNION ALL
    SELECT D.ID AS OriginalDoc,
           D.ObjectTypeId AS OriginalDocType
    FROM dbo.Document AS D
        JOIN #IDList AS IDList
            ON IDList.ID = D.ID
        JOIN #ParentDocTypes AS PDT
            ON PDT.ID = D.ObjectTypeId
    WHERE @IDList IS NOT NULL
    UNION ALL
    SELECT d.ID,
           @OtrazhenityVyruchkiSellera
    FROM dbo.Document AS d
        JOIN #BillingDocs AS BD
            ON BD.ID = d.ParentDocumentID
               AND d.ObjectTypeId = @OtrazhenityVyruchkiSellera
    OPTION (MAXDOP 8);
    DROP TABLE IF EXISTS #ParentDocs;
    CREATE TABLE #ParentDocs
    (
        OriginalDoc BIGINT NOT NULL,
        ParentDoc BIGINT NOT NULL,
        OriginalDocType BIGINT NOT NULL,
        OriginDocState BIGINT NULL INDEX ParentDoc CLUSTERED (ParentDoc)
    );
    INSERT #ParentDocs
    (
        OriginalDoc,
        ParentDoc,
        OriginalDocType,
        OriginDocState
    )
    SELECT d.ID AS OriginalDoc,
           d.ParentDocumentID AS ParentDoc,
           d.ObjectTypeId AS OriginalDocType,
           o.StateID AS OriginDocState
    FROM dbo.Document d
        JOIN #ParentDocKeys AS pdk
            ON pdk.OriginalDoc = d.ID
               AND d.ObjectTypeId = pdk.OriginalDocType
        JOIN dbo.Object AS o
            ON o.ID = d.ID
    WHERE d.ParentDocumentID IS NOT NULL
          AND pdk.OriginalDocType <> @OtrazhenityVyruchkiSellera
    UNION ALL
    SELECT d.ParentDocumentID AS OriginalDoc,
           d.ID AS ParentDoc,
           d.ObjectTypeId AS OriginalDocType,
           o.StateID AS OriginDocState
    FROM dbo.Document d
        JOIN #ParentDocKeys AS pdk
            ON pdk.OriginalDoc = d.ID
               AND d.ObjectTypeId = pdk.OriginalDocType
               AND pdk.OriginalDocType = @OtrazhenityVyruchkiSellera
        JOIN dbo.Object AS o
            ON o.ID = d.ID
    WHERE d.ParentDocumentID IS NOT NULL
    OPTION (MAXDOP 8);
    --новая приёмкая излишков    
    DECLARE @NewInboundProcessDirID BIGINT
        = dbo.ObjectGetBySysName('DocumentProviderRqstAttribute', 'NewInboundProcess');
    DROP TABLE IF EXISTS #NewIboundDocs;
    CREATE TABLE #NewIboundDocs
    (
        ID BIGINT NOT NULL INDEX ID UNIQUE CLUSTERED
    );
    INSERT #NewIboundDocs
    (
        ID
    )
    SELECT PD.OriginalDoc AS ID
    FROM #ParentDocs AS PD
        JOIN dbo.ObjectDirectory od
            ON od.ObjectID = PD.ParentDoc
               AND od.DirectoryID = @NewInboundProcessDirID
    OPTION (MAXDOP 8);

    DROP TABLE IF EXISTS #PreDocs;
    CREATE TABLE #PreDocs
    (
        ID BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL,
        OriginalDocID BIGINT NOT NULL,
        Active TINYINT NOT NULL,
        pNum SMALLINT NULL,
        IsNewInbound TINYINT NULL,
        IsInGoingType TINYINT NOT NULL,
        IsOutGoingType TINYINT NOT NULL,
        NoCosting TINYINT NOT NULL INDEX OriginalDocID CLUSTERED (OriginalDocID)
    );

    --Получение документов и их статусов по дате и по списку SrcID
    INSERT #PreDocs
    (
        ID,
        DocTypeID,
        Posted,
        State,
        OriginalDocID,
        Active,
        pNum,
        IsInGoingType,
        IsOutGoingType,
        NoCosting
    )
    -- основной массив документов с выборкой по дате учета
    SELECT D.ID AS ID,
           D.ObjectTypeId AS DocTypeID,
           CASE
               WHEN ISNULL(ObjState.Name, 'Формируется') = 'Формируется' THEN
                   0
               ELSE
                   ISNULL(DocState.Active, 0)
           END AS Posted,
           ISNULL(ObjState.Name, 'Формируется') AS State,
           D.ID AS OriginalDocID,
           ISNULL(DocState.Active, 0) AS Active,
           D.pNum AS pNum,
           RT.CommonIrIngoing AS IsInGoingType,
           RT.CommonIROutGoing AS IsOutGoingType,
           RT.NoCosting AS NoCosting
    FROM dbo.Document AS D
        INNER JOIN dbo.Object AS o
            ON (D.ID = o.ID)
        JOIN #ReconsileTypes AS RT
            ON RT.ID = D.ObjectTypeId
        LEFT JOIN dbo.State AS DocState
            ON DocState.ID = o.StateID
        LEFT JOIN dbo.Object AS ObjState
            ON ObjState.ID = o.StateID
    WHERE (
              @IDList IS NULL
              AND D.AccountingDate
          BETWEEN @BeginPeriod AND @EndPeriod
              AND RT.ID <> @OtrazhenityVyruchkiSellera
          )
    UNION ALL
    -- основной массив документов выборкой по списку SrcID
    SELECT D.ID,
           o.ObjectTypeID AS DocTypeID,
           CASE
               WHEN ISNULL(ObjState.Name, 'Формируется') = 'Формируется' THEN
                   0
               ELSE
                   ISNULL(DocState.Active, 0)
           END AS Posted,
           ISNULL(ObjState.Name, 'Формируется') AS State,
           D.ID AS OriginalDocID,
           ISNULL(DocState.Active, 0) AS Active,
           D.pNum AS pNum,
           RT.CommonIrIngoing AS IsInGoingType,
           RT.CommonIROutGoing AS IsOutGoingType,
           RT.NoCosting
    FROM dbo.Document AS D
        JOIN #IDList AS IDLIST
            ON IDLIST.ID = D.ID
        INNER JOIN dbo.Object AS o
            ON (IDLIST.ID = o.ID)
        JOIN #ReconsileTypes AS RT
            ON RT.ID = D.ObjectTypeId
               AND RT.ID <> @OtrazhenityVyruchkiSellera
        LEFT JOIN dbo.State AS DocState
            ON DocState.ID = o.StateID
        LEFT JOIN dbo.Object AS ObjState
            ON ObjState.ID = o.StateID
    WHERE @IDList IS NOT NULL
    UNION ALL
    -- платежное поручение с выборкой по дате  
    SELECT bo.DocumentID,
           @PlatezhnoyePorucheniye,
           CASE
               WHEN ISNULL(ObjState.Name, 'Формируется') = 'Формируется' THEN
                   0
               ELSE
                   ISNULL(DocState.Active, 0)
           END AS Posted,
           ISNULL(ObjState.Name, 'Формируется') AS State,
           bo.DocumentID,
           ISNULL(DocState.Active, 0) AS Active,
           NULL AS pNum,
           0,
           0,
           1
    FROM #BankOperations AS bo
        JOIN dbo.Document AS o
            ON o.ID = bo.DocumentID
               AND o.ObjectTypeID = @PlatezhnoyePorucheniye
        LEFT JOIN dbo.State AS DocState
            ON DocState.ID = o.StateID
        LEFT JOIN dbo.Object AS ObjState
            ON ObjState.ID = o.StateID
        LEFT JOIN dbo.Document AS d
            ON d.ID = bo.DocumentID
               AND d.AccountingDate
               BETWEEN @BeginPeriod AND @EndPeriod
    WHERE @IDList IS NULL
          AND bo.AccountingDate
          BETWEEN @BeginPeriod AND @EndPeriod
          AND d.ID IS NULL
    UNION ALL

    -- Получение документов оснований для корректирующих документов
    SELECT D.ID,
           CASE
               WHEN pd.OriginalDocType IN ( @aktVypolnennyhRabotaAgentapoDostavkeVhodyaschiyStorno,
                                            @NakladnayaVozvrataPostavschikuKorrektirovka
                                          ) THEN
                   D.ObjectTypeId
               ELSE
                   pd.OriginalDocType
           END,
           1,
           ISNULL(DocState.Name, 'Формируется'),
           pd.OriginalDoc,
           1,
           D.pNum,
           RT.CommonIrIngoing AS IsInGoingType,
           RT.CommonIROutGoing AS IsOutGoingType,
           RT.NoCosting
    FROM #ParentDocs pd
        JOIN dbo.Document AS D
            ON D.ID = pd.ParentDoc
               AND pd.OriginalDocType IN ( @CreditNote, @AktPriyemkiPeredachi, @AktPriyemkiPeredachiPredvaritelno,
                                           @aktVypolnennyhRabotaAgentapoDostavkeVhodyaschiyStorno,
                                           @OtrazhenityVyruchkiSellera
                                         )
        LEFT JOIN dbo.State AS DocState
            ON DocState.ID = pd.OriginDocState
        JOIN #ReconsileTypes AS RT
            ON RT.ID = D.ObjectTypeId


    -- Выборка документов где не стоит учетная дата
    UNION ALL
    SELECT D.ID,
           o.ObjectTypeID AS DocTypeID,
           CASE
               WHEN ISNULL(ObjState.Name, 'Формируется') = 'Формируется' THEN
                   0
               ELSE
                   ISNULL(DocState.Active, 0)
           END AS Posted,
           ISNULL(ObjState.Name, 'Формируется') AS State,
           D.ID AS OriginalDocID,
           ISNULL(DocState.Active, 0),
           D.pNum,
           RT.CommonIrIngoing AS IsInGoingType,
           RT.CommonIROutGoing AS IsOutGoingType,
           RT.NoCosting
    FROM dbo.Document AS D
        INNER JOIN dbo.Object AS o
            ON (D.ID = o.ID)
        JOIN #ReconsileTypes AS RT
            ON RT.ID = D.ObjectTypeId
        LEFT JOIN dbo.State AS DocState
            ON DocState.ID = o.StateID
        LEFT JOIN dbo.Object AS ObjState
            ON ObjState.ID = o.StateID
        LEFT JOIN #BankOperations AS bo
            ON bo.DocumentID = D.ID
    WHERE @IDList IS NULL
          AND D.Date
          BETWEEN @BeginPeriod AND @EndPeriod
          AND D.AccountingDate IS NULL
          AND bo.DocumentID IS NULL
    OPTION (MAXDOP 8);

    CREATE NONCLUSTERED INDEX DocTypeID ON #PreDocs (DocTypeID);
    BEGIN
        IF @TurnMetrics > 0
            SELECT '#PreDocs',
                   DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;


--HumanAdvanceVATReport
Declare @IDsHumanAdvanceVATReport dbo.IDTable;
INSERT INTO @IDsHumanAdvanceVATReport (ID)
Select D.ID from #PreDocs AS D  Where D.DocTypeID = @HumanAdvanceVATReport
DROP TABLE IF EXISTS #HumanAdvanceVATReport;
create table #HumanAdvanceVATReport( DateUnloading VARCHAR(255),
    Npp TINYINT,
    DeletionMark VARCHAR(5),
    DocumentType VARCHAR(50),
    MetazonType VARCHAR(8000),
    SrcID bigint,
    Num bigint,
    Date VARCHAR(255),
    Comment VARCHAR(8000),
    Organisation VARCHAR(10),
    ContractID VARCHAR(20),
    Responsible VARCHAR(3),
    Division BIGINT,
    AdvancesAccrualAmount DECIMAL(18, 2),
    AdvancesAccrualVatAmount DECIMAL(18, 2),
    AdvancesWriteoffAmount DECIMAL(18, 2),
    AdvancesWriteoffVatAmount DECIMAL(18, 2),
    IrAdvancesAccrualAmount DECIMAL(18, 2),
    IrAdvancesAccrualVatAmount DECIMAL(18, 2),
    DocumentSum DECIMAL(18, 2))																					
insert INTO  #HumanAdvanceVATReport 
exec e1c.HumanAdvanceVATReportExportTo1C @IDsHumanAdvanceVATReport
;
--



    --Не все аккрулы должны попадать в 1С SDMETA-31129  
    DECLARE @DirectoryID BIGINT
        = dbo.ObjectGetBySysName('DirectoryGroupSettings', 'DirectoryGroupSettingsNoCreateAccruals');
    DECLARE @BudgetClaimObjectTypeID BIGINT = dbo.ObjectTypeGetBySysName('DocumentBudgetClaim');
    DECLARE @ExportProhibitionDirectoryID BIGINT = dbo.ObjectGetBySysName('DirectorySystem', 'ExportProhibition');
    DECLARE @MarketplaceDir BIGINT = dbo.ObjectGetBySysName('DirectoryGroupSettings', 'Marketplace');
    DROP TABLE IF EXISTS #LockingContracts;
    CREATE TABLE #LockingContracts
    (
        ContractID BIGINT NOT NULL,
        DocID BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL INDEX ConractID CLUSTERED (ContractID)
    );
    INSERT #LockingContracts
    (
        ContractID,
        DocID,
        DocTypeID
    )
    SELECT DocData.ContractID AS ContractID,
           d.OriginalDocID AS DocID,
           d.DocTypeID AS DocTypeID
    FROM #PreDocs AS d
        JOIN dbo.Document AS DocData
            ON DocData.ID = d.OriginalDocID
               AND d.DocTypeID IN ( @ReyestrTranzaktsiyKPlatezhnomuPorucheniyuOtPAOnlaynEkvayring, @AktOBrake,
                                    @AktONedostachi, @AktOBrakeVes, @AktOBrakeVes, @KomissionnoyeVoznagrazhdeniye
                                  )
    WHERE DocData.ContractID IS NOT NULL
    OPTION (MAXDOP 8);
    DROP TABLE IF EXISTS #NoFIAccruals;
    CREATE TABLE #NoFIAccruals
    (
        OriginalDocID BIGINT NOT NULL INDEX OriginalDocID UNIQUE CLUSTERED (OriginalDocID)
    );
    INSERT #NoFIAccruals
    (
        OriginalDocID
    )
    SELECT d.OriginalDocID AS OriginalDocID
    FROM #PreDocs AS d
        JOIN dbo.Object AS o
            ON o.ID = d.ID
               AND o.ObjectTypeID = @BudgetClaimObjectTypeID
        JOIN dbo.DocumentSumByBudget AS dsbb
            ON dsbb.DocumentID = d.ID
        JOIN dbo.ObjectDirectory AS od
            ON od.ObjectID = dsbb.BudgetAccountID
               AND od.DirectoryID = @DirectoryID
    WHERE d.DocTypeID IN ( @AktPriyemkiPeredachi, @AktPriyemkiPeredachiPredvaritelno )
          AND d.OriginalDocID <> d.ID
    UNION
    SELECT d.OriginalDocID
    FROM #PreDocs AS d
        JOIN dbo.Object AS o
            ON o.ID = d.ID
               AND o.ObjectTypeID = @BudgetClaimObjectTypeID
        JOIN dbo.ObjectDirectory AS od
            ON od.ObjectID = d.ID
               AND od.DirectoryID = @DirectoryID
    WHERE d.DocTypeID IN ( @AktPriyemkiPeredachi, @AktPriyemkiPeredachiPredvaritelno )
          AND d.OriginalDocID <> d.ID
    UNION
    SELECT LC.DocID
    FROM #LockingContracts AS LC
        INNER JOIN dbo.ObjectDirectory AS od
            ON od.ObjectID = LC.ContractID
               AND od.DirectoryID = @ExportProhibitionDirectoryID
               AND LC.DocTypeID IN ( @ReyestrTranzaktsiyKPlatezhnomuPorucheniyuOtPAOnlaynEkvayring, @AktOBrake,
                                     @AktONedostachi, @AktOBrakeVes, @AktOBrakeVes
                                   )
    UNION
    SELECT LC.DocID
    FROM #LockingContracts AS LC
        INNER JOIN dbo.ObjectDirectory AS od
            ON od.ObjectID = LC.ContractID
               AND od.DirectoryID = @ContractStorage
               AND LC.DocTypeID IN ( @AktOBrake, @AktONedostachi )
    UNION
    SELECT LC.DocID
    FROM #LockingContracts AS LC
        JOIN dbo.Object o
            ON o.ID = LC.ContractID
               AND o.ObjectTypeID = @ContractCommission
    WHERE LC.DocTypeID IN ( @AktOBrake, @AktONedostachi, @AktOBrakeVes, @AktONedostacheVes )
    UNION
    SELECT LC.DocID
    FROM #LockingContracts AS LC
        INNER JOIN dbo.ObjectDirectory AS od
            ON od.ObjectID = LC.ContractID
               AND od.DirectoryID = @MarketplaceDir
               AND LC.DocTypeID IN ( @KomissionnoyeVoznagrazhdeniye )
    OPTION (MAXDOP 8);

    --получение разделителей по операциям

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#NoFIAccruals',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DECLARE @DirAccDelimTypeId BIGINT = dbo.ObjectTypeGetBySysName('DirectioryAccDelim');

    DROP TABLE IF EXISTS #DocsExport;
    CREATE TABLE #DocsExport
    (
        ID BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL,
        OriginalDocID BIGINT NULL,
        Mandat VARCHAR(15) NULL,
        pNum SMALLINT NULL,
        IsIngoingType TINYINT NOT NULL,
        ISOutgoingType TINYINT NOT NULL,
        NoCosting TINYINT NOT NULL INDEX OriginalDocID CLUSTERED (ID)
    );
    INSERT #DocsExport
    (
        ID,
        DocTypeID,
        Posted,
        State,
        OriginalDocID,
        Mandat,
        pNum,
        IsIngoingType,
        ISOutgoingType,
        NoCosting
    )
    SELECT DISTINCT
           PreDocs.ID AS ID,
           PreDocs.DocTypeID AS DocTypeID,
           PreDocs.Posted AS Posted,
           PreDocs.State AS State,
           PreDocs.OriginalDocID AS OriginalDocID,
           o.SysName AS Mandat,
           PreDocs.pNum AS pNum,
           PreDocs.IsInGoingType AS IsInGoingType,
           PreDocs.IsOutGoingType AS IsOutGoingType,
           PreDocs.NoCosting AS NoCosting
    FROM #PreDocs AS PreDocs
        LEFT JOIN dbo.ExportOperationObject AS ExpOpObj
            ON PreDocs.OriginalDocID = ExpOpObj.ObjectID
        LEFT JOIN dbo.ObjectDirectory AS ObjDir
            ON ObjDir.ObjectID = ExpOpObj.ExportOperationID
        LEFT JOIN dbo.Object AS o
            ON o.ID = ObjDir.DirectoryID
               AND o.ObjectTypeID = @DirAccDelimTypeId
    WHERE NOT (
                  PreDocs.DocTypeID IN ( @AktPriyemkiPeredachi, @AktPriyemkiPeredachiPredvaritelno )
                  AND PreDocs.ID <> PreDocs.OriginalDocID
              )
    OPTION (MAXDOP 8);
    CREATE NONCLUSTERED INDEX DocTypeID
    ON #DocsExport (DocTypeID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#DocsExport',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DROP TABLE IF EXISTS #DocGMP;
    CREATE TABLE #DocGMP
    (
        DocID BIGINT NOT NULL,
        GMPID BIGINT NOT NULL INDEX DocID CLUSTERED (GMPID)
    );
    INSERT #DocGMP
    (
        DocID,
        GMPID
    )
    SELECT D.ID AS docID,
           ISNULL(D.GlobalMarketPlaceID, GMPDef.ID) AS GMPID
    FROM dbo.Document AS D
        JOIN #PreDocs AS PD
            ON PD.ID = D.ID
        JOIN dbo.GlobalMarketPlaceDirectory AS GMPDef
            ON GMPDef.MarketPlaceID = 1;

    DROP TABLE IF EXISTS #DocGMPInfo;
    CREATE TABLE #DocGMPInfo
    (
        DocID BIGINT NOT NULL,
        GMPID BIGINT NOT NULL,
        MandatID BIGINT NULL,
        NDS NUMERIC(5, 2) NULL,
        Currency BIGINT NOT NULL INDEX DocID CLUSTERED (MandatID)
    );
    INSERT #DocGMPInfo
    (
        DocID,
        GMPID,
        MandatID,
        NDS,
        Currency
    )
    SELECT d.DocID AS DocID,
           d.GMPID,
           GMP.DelimetrID AS MandatID,
           ISNULL(GMP.VAT, GMPDef.VAT) AS NDS,
           ISNULL(GMP.CurrencyID, GMPDef.CurrencyID) AS Currency
    FROM #DocGMP AS d
        JOIN dbo.GlobalMarketPlaceDirectory AS GMP
            ON GMP.ID = d.GMPID
        JOIN dbo.GlobalMarketPlaceDirectory AS GMPDef
            ON GMPDef.MarketPlaceID = 1
    OPTION (MAXDOP 8);
    DROP TABLE IF EXISTS #Mandats;
    CREATE TABLE #Mandats
    (
        DocID BIGINT NOT NULL,
        GMPID BIGINT NOT NULL,
        Mandat VARCHAR(15) NULL,
        NDS NUMERIC(5, 2) NULL,
        Currency BIGINT NOT NULL INDEX DocID CLUSTERED (DocID)
    );
    INSERT #Mandats
    (
        DocID,
        GMPID,
        Mandat,
        NDS,
        Currency
    )
    SELECT d.DocID AS DocID,
           d.GMPID AS GMPID,
           o.SysName AS Mandat,
           d.NDS AS NDS,
           d.Currency AS Currency
    FROM #DocGMPInfo AS d
        LEFT JOIN dbo.Object AS o
            ON o.ID = d.MandatID;
    DROP TABLE IF EXISTS #Docs;
    CREATE TABLE #Docs
    (
        ID BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        Amount NUMERIC(15, 2) NOT NULL,
        AmountCurr NUMERIC(15, 2) NOT NULL,
        Posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL,
        OriginalDocID BIGINT NOT NULL,
        Mandat VARCHAR(15) NOT NULL,
        NDS NUMERIC(5, 2) NULL,
        Currency BIGINT NOT NULL,
		DocCurrency BIGINT NOT NULL,
        ContractID BIGINT NULL,
        ParentDocument BIGINT NULL,
        pNum SMALLINT NOT NULL,
        OriginalDocTypeID BIGINT NOT NULL,
        IsMarketPlaceDir TINYINT NOT NULL,
        IsNewInbound TINYINT NULL,
        gmp BIGINT NULL,
        OperType BIGINT NULL,
        IsIngoingType TINYINT NOT NULL,
        IsOutgoingType TINYINT NOT NULL,
        NoCosting TINYINT NOT NULL,
        ClearingRO TINYINT NOT NULL,
		ISVGO TINYINT NOT null
    );

    INSERT #Docs
    (
        ID,
        DocTypeID,
        AccountingDate,
        Date,
        Amount,
        AmountCurr,
        Posted,
        State,
        OriginalDocID,
        Mandat,
        NDS,
        Currency,
		DocCurrency,
        ContractID,
        ParentDocument,
        pNum,
        OriginalDocTypeID,
        IsMarketPlaceDir,
        IsNewInbound,
        gmp,
        OperType,
        IsIngoingType,
        IsOutgoingType,
        NoCosting,
        ClearingRO,
		ISVGO
    )
    SELECT PreDocs.ID AS ID,
           PreDocs.DocTypeID AS DocTypeID,
           d.AccountingDate AS AccountingDate,
           d.Date AS Date,
           ISNULL(d.Amount, 0) AS Amount,
           ISNULL(d.AmountCurr, 0) AS AmountCurr,
           CASE
               WHEN Accruals.OriginalDocID IS NOT NULL THEN
                   0
               ELSE
                   PreDocs.Posted
           END AS Posted,
           CASE
               WHEN Accruals.OriginalDocID IS NULL
                    OR d.ObjectTypeId = @KomissionnoyeVoznagrazhdeniye THEN
                   PreDocs.State
               ELSE
                   'Блокирован'
           END AS State,
           PreDocs.OriginalDocID AS OriginalDocID,
           COALESCE(PreDocs.Mandat, gmp.Mandat, 'MSK') AS Mandat,
           gmp.NDS AS NDS,
           gmp.Currency AS Currency,
		   d.CurrencyID AS DocCurrency,
           CASE
               WHEN R.ID IS NOT NULL THEN
                   d.ContractID
               ELSE
                   NULL
           END AS ContractID,
           d.ParentDocumentID AS ParentDocumentID,
           ISNULL(ot.pNum, ISNULL(PreDocs.pNum, d.pNum)) AS pNum,
           d.ObjectTypeId AS OriginalDocTypeID,
           CASE
               WHEN d.ObjectTypeId = @KomissionnoyeVoznagrazhdeniye
                    AND Accruals.OriginalDocID IS NOT NULL THEN
                   1
               ELSE
                   0
           END AS IsMarketPlaceDir,
           CASE
               WHEN NewInbound.ID IS NULL THEN
                   0
               ELSE
                   1
           END AS IsNewInbound,
           gmp.GMPID AS gmp,
           ot.OperType AS Opertype,
           PreDocs.IsIngoingType AS IsIngoingType,
           PreDocs.ISOutgoingType AS ISOutgoingType,
           PreDocs.NoCosting AS NoCosting,
           ISNULL(ot.Clearing, 0) + ISNULL(ot.RestOps, 0) AS ClearingRO,
		   ISNULL(R.ISVGO, 0) AS ISVGO
    FROM #DocsExport AS PreDocs
        JOIN dbo.Document AS d
            ON d.ID = PreDocs.OriginalDocID
        LEFT JOIN #NoFIAccruals AS Accruals WITH (INDEX(OriginalDocID)FORCESEEK)
            ON Accruals.OriginalDocID = PreDocs.OriginalDocID
        LEFT JOIN #NewIboundDocs AS NewInbound WITH (INDEX(ID)FORCESEEK)
            ON NewInbound.ID = PreDocs.OriginalDocID
        LEFT JOIN #ReconsileTypes R
            ON R.ID = d.ObjectTypeId
               AND R.ContractInHeader = 1
        LEFT JOIN #OperTypes ot
            ON ot.id = PreDocs.DocTypeID
        JOIN #Mandats AS gmp
            ON gmp.DocID = PreDocs.OriginalDocID
    OPTION (MAXDOP 8);

    CREATE STATISTICS DocTypeID_Stat ON #Docs (DocTypeID, ID, pNum);
    CREATE CLUSTERED INDEX DocTypeID
    ON #Docs (
                 DocTypeID,
                 ID,
                 pNum
             )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    CREATE STATISTICS ContractID_Stat ON #Docs (ContractID);
    CREATE NONCLUSTERED INDEX ContractID
    ON #Docs (ContractID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    DROP TABLE #PreDocs;
    DROP TABLE #DocsExport;
    DROP TABLE #NoFIAccruals;
    DROP TABLE #NewIboundDocs;
    DROP TABLE #LockingContracts;
    DROP TABLE #ParentDocKeys;
    DROP TABLE #ParentDocs;

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Docs',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #OperDocs;
    CREATE TABLE #OperDocs
    (
		DocumentID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        DocTypeID BIGINT NOT NULL,
        OriginalDocID BIGINT NULL,
        Posted TINYINT NULL,
        Mandat VARCHAR(15) NULL,
        NDS NUMERIC(15, 2) NULL,
        Currency BIGINT NOT NULL,
		DocCurrency BIGINT NOT NULL,
        State NVARCHAR(50) NULL,
        OriginalDocTypeID BIGINT NULL,
        DocGMP BIGINT NULL,
        IsIngoingType TINYINT NOT NULL,
        IsOutGoingType TINYINT NOT NULL,
        NoCosting TINYINT NOT NULL,
        OperType BIGINT NOT NULL,
        pNum SMALLINT NULL,
        ClearingRO TINYINT NOT NULL,
		ISVGO TINYINT NOT NULL,
        IsParentDoc TINYINT NOT NULL,
        ContractID BIGINT NULL,
        IsMarketPlaceDir TINYINT NOT NULL
    );

    INSERT #OperDocs
    (
        DocumentID,
        AccountingDate,
        Date,
        DocTypeID,
        OriginalDocID,
        Posted,
        Mandat,
        NDS,
        Currency,
		DocCurrency,
        State,
        OriginalDocTypeID,
        DocGMP,
        IsIngoingType,
        IsOutGoingType,
        NoCosting,
        OperType,
        pNum,
        ClearingRO,
		ISVGO,
        IsParentDoc,
        ContractID,
        IsMarketPlaceDir
    )
    SELECT D.ID AS DocumentID,
           D.AccountingDate AS AccountingDate,
           D.Date AS Date,
           D.DocTypeID AS DocTypeID,
           D.OriginalDocID AS OriginalDocID,
           D.Posted AS Posted,
           D.Mandat AS Mandat,
           D.NDS,
           D.Currency,
		   D.DocCurrency,
           D.State AS State,
           D.OriginalDocTypeID AS OriginalDocTypeID,
           D.gmp AS DocGMP,
           D.IsIngoingType AS IsIngoingType,
           D.IsOutgoingType AS IsOutgoingType,
           D.NoCosting AS NoCosting,
           D.OperType AS OperType,
           D.pNum AS pNum,
           D.ClearingRO AS ClearingRO,
		   D.IsVGO AS IsVGO,
           CASE
               WHEN D.OriginalDocID = D.ID THEN
                   0
               ELSE
                   1
           END AS IsParentDoc,
           D.ContractID AS ContractID,
           D.IsMarketPlaceDir AS IsMarketPlaceDir
    FROM #Docs AS D
    WHERE D.OperType IS NOT NULL
          AND D.OriginalDocID = D.ID
    OPTION (MAXDOP 8);
    CREATE STATISTICS DocumentID_Stat
    ON #OperDocs
    (
        DocumentID,
        OperType,
        pNum
    );
    CREATE CLUSTERED INDEX DocumentID
    ON #OperDocs (
                     DocumentID,
                     OperType,
                     pNum
                 )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#OperDocs',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #ParentOperDocs;
    CREATE TABLE #ParentOperDocs
    (
        DocumentID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        DocTypeID BIGINT NOT NULL,
        OriginalDocID BIGINT NULL,
        Posted TINYINT NULL,
        Mandat VARCHAR(15) NULL,
        NDS NUMERIC(5, 2) NULL,
        Currency BIGINT NOT NULL,
		DocCurrency BIGINT NOT null,
        State NVARCHAR(50) NULL,
        OriginalDocTypeID BIGINT NULL,
        DocGMP BIGINT NULL,
        IsIngoingType TINYINT NOT NULL,
        IsOutGoingType TINYINT NOT NULL,
        NoCosting TINYINT NOT NULL,
        OperType BIGINT NOT NULL,
        ClearingRO TINYINT NOT NULL,
		ISVGO TINYINT NOT NULL,
        IsParentDoc TINYINT NOT NULL,
        ContractID BIGINT NULL,
        IsMarketPlaceDir TINYINT NOT NULL
    );

    INSERT #ParentOperDocs
    (
        DocumentID,
        AccountingDate,
        Date,
        DocTypeID,
        OriginalDocID,
        Posted,
        Mandat,
        NDS,
        Currency,
		DocCurrency,
        State,
        OriginalDocTypeID,
        DocGMP,
        IsIngoingType,
        IsOutGoingType,
        NoCosting,
        OperType,
        ClearingRO,
		ISVGO,
        IsParentDoc,
        ContractID,
        IsMarketPlaceDir
    )
    SELECT DISTINCT
           D.ID AS DocumentID,
           D.AccountingDate AS AccountingDate,
           D.Date AS Date,
           D.DocTypeID AS DocTypeID,
           D.OriginalDocID AS OriginalDocID,
           D.Posted AS Posted,
           D.Mandat AS Mandat,
           D.NDS AS NDS,
           D.Currency AS Currency,
		   D.DocCurrency AS DocCurrency,
           D.State AS State,
           D.OriginalDocTypeID AS OriginalDocTypeID,
           D.gmp AS DocGMP,
           D.IsIngoingType AS IsIngoingType,
           D.IsOutgoingType AS IsOutgoingType,
           D.NoCosting AS NoCosting,
           D.OperType AS OperType,
           D.ClearingRO AS ClearingRO,
		   D.ISVGO AS ISVGO,
           CASE
               WHEN D.OriginalDocID = D.ID THEN
                   0
               ELSE
                   1
           END AS IsParentDoc,
           D.ContractID AS ContractID,
           D.IsMarketPlaceDir AS IsMarketPlaceDir
    FROM #Docs AS D
    WHERE D.OperType IS NOT NULL
          AND D.OriginalDocID <> D.ID
    OPTION (MAXDOP 8);
    CREATE STATISTICS DocumentID_Stat
    ON #ParentOperDocs
    (
        DocumentID,
        OperType
    );
    CREATE CLUSTERED INDEX DocumentID
    ON #ParentOperDocs (
                           DocumentID,
                           OperType
                       )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#ParentOperDocs',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #CommonOperKeys;
    CREATE TABLE #CommonOperKeys
    (
        id BIGINT NOT NULL,
        DocumentID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        DocTypeID BIGINT NOT NULL,
        OriginalDocID BIGINT NULL,
        Posted TINYINT NULL,
        Mandat VARCHAR(15) NULL,
        NDS NUMERIC(5, 2) NULL,
        Currency BIGINT NOT NULL,
		DocCurrency BIGINT NOT NULL,
        State NVARCHAR(50) NULL,
        OriginalDocTypeID BIGINT NULL,
        DocGMP BIGINT NULL,
        pNum SMALLINT NOT NULL,
        IsIngoingType TINYINT NOT NULL,
        IsOutGoingType TINYINT NOT NULL,
        NoCosting TINYINT NOT NULL,
        ContractID BIGINT NULL,
        ClearingRO TINYINT NOT NULL,
		ISVGO TINYINT NOT NULL,
        IsMarketPlaceDir TINYINT NOT NULL
    );

    INSERT #CommonOperKeys
    (
        id,
        DocumentID,
        AccountingDate,
        Date,
        DocTypeID,
        OriginalDocID,
        Posted,
        Mandat,
        NDS,
        Currency,
		DocCurrency,
        State,
        OriginalDocTypeID,
        DocGMP,
        pNum,
        IsIngoingType,
        IsOutGoingType,
        NoCosting,
        ContractID,
        ClearingRO,
		ISVGO,
        IsMarketPlaceDir
    )
    SELECT Op.ID AS ID,
           D.DocumentID AS DocumentID,
           D.AccountingDate AS AccountingDate,
           D.Date AS Date,
           D.DocTypeID AS DocTypeID,
           D.OriginalDocID AS OriginalDocID,
           D.Posted AS Posted,
           D.Mandat AS Mandat,
           D.NDS AS NDS,
           D.Currency AS Currency,
		   D.DocCurrency AS DocCurrency,
           D.State AS State,
           D.OriginalDocTypeID AS OriginalDocTypeID,
           D.DocGMP AS DocGMP,
           Op.pNum AS pNum,
           D.IsIngoingType AS IsIngoingType,
           D.IsOutGoingType AS IsOutgoingType,
           D.NoCosting AS NoCosting,
           D.ContractID AS ContractID,
           D.ClearingRO AS ClearingRO,
		   D.ISVGO AS ISVGO,
           D.IsMarketPlaceDir AS IsMarketPlaceDir
    FROM #OperDocs AS D
        JOIN dbo.Operation_new AS Op WITH (INDEX(IX_DocumentID_ObjectTypeID_pNum))
            ON Op.DocumentID = D.DocumentID
               AND Op.ObjectTypeID = D.OperType
               AND Op.pNum = D.pNum
    OPTION (MAXDOP 8);

    INSERT #CommonOperKeys
    (
        id,
        DocumentID,
        AccountingDate,
        Date,
        DocTypeID,
        OriginalDocID,
        Posted,
        Mandat,
        NDS,
        Currency,
		DocCurrency,
        State,
        OriginalDocTypeID,
        DocGMP,
        pNum,
        IsIngoingType,
        IsOutGoingType,
        NoCosting,
        ContractID,
        ClearingRO,
		ISVGO,
        IsMarketPlaceDir
    )
    SELECT Op.ID AS ID,
           D.DocumentID AS DocumentID,
           D.AccountingDate AS AccountingDate,
           D.Date AS Date,
           D.DocTypeID AS DocTypeID,
           D.OriginalDocID AS OriginalDocID,
           D.Posted AS Posted,
           D.Mandat AS Mandat,
           D.NDS AS NDS,
           D.Currency AS Currency,
		   D.DocCurrency AS DocCurrency,
           D.State AS State,
           D.OriginalDocTypeID AS OriginalDocTypeID,
           D.DocGMP AS DocGMP,
           Op.pNum AS pNum,
           D.IsIngoingType AS IsIngoingType,
           D.IsOutGoingType AS IsOutgoingType,
           D.NoCosting AS NoCosting,
           D.ContractID AS ContractID,
           D.ClearingRO AS ClearingRO,
		   D.ISVGO AS ISVGO,
           D.IsMarketPlaceDir AS IsMarketPlaceDir
    FROM #ParentOperDocs AS D
        JOIN dbo.Operation_new AS Op WITH (INDEX(IX_DocumentID_ObjectTypeID_pNum))
            ON Op.DocumentID = D.DocumentID
               AND Op.ObjectTypeID = D.OperType
    OPTION (MAXDOP 8);
    CREATE STATISTICS ID_Stat ON #CommonOperKeys (id, pNum);
    CREATE CLUSTERED INDEX ID
    ON #CommonOperKeys (
                           id,
                           pNum
                       )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    DROP TABLE #OperDocs;
    DROP TABLE #ParentOperDocs;
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#CommonOperKeys',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #MultyContractOperations;
    CREATE TABLE #MultyContractOperations
    (
        opid BIGINT NOT NULL,
        docid BIGINT NOT NULL,
        doctypeid BIGINT NOT NULL,
        STATE VARCHAR(50) NOT NULL,
        Mandat VARCHAR(10) NOT NULL,
		DocCurrency BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        ContractID BIGINT NULL,
        pnum SMALLINT NULL
    );
    INSERT #MultyContractOperations
    (
        opid,
        docid,
        doctypeid,
        STATE,
        Mandat,
		DocCurrency,
        Posted,
        AccountingDate,
        Date,
        ContractID,
        pnum
    )
    SELECT Op.ID,
           D.ID,
           D.DocTypeID,
           D.State,
           D.Mandat,
		   D.DocCurrency As DocCurrency ,
           D.Posted,
           D.AccountingDate,
           D.Date,
           --[ONEC-6603]
           D.ContractID,
           Op.pNum
    FROM #Docs AS D
        JOIN dbo.Operation_new AS Op WITH (INDEX(IX_DocumentID_ObjectTypeID_pNum)FORCESEEK)
            ON D.ID = Op.DocumentID
    /*AND D.OperType = Op.ObjectTypeID
		AND D.pNum = Op.pNum*/
    WHERE D.DocTypeID IN ( @PlatezhnoyePorucheniye )
    OPTION (MAXDOP 8);
    CREATE STATISTICS opid_stat ON #MultyContractOperations (opid, pnum);
    CREATE CLUSTERED INDEX opid
    ON #MultyContractOperations (
                                    opid,
                                    pnum
                                )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    DROP TABLE IF EXISTS #ContractsInOperations;
    CREATE TABLE #ContractsInOperations
    (
        opid BIGINT NOT NULL,
        docid BIGINT NOT NULL,
        doctypeid BIGINT NOT NULL,
        Contract BIGINT NULL,
		DocCurrency BIGINT NOT NULL,
        STATE VARCHAR(50) NOT NULL,
        Amount NUMERIC(15, 2) NOT NULL,
        IsDebit TINYINT NOT NULL,
        Mandat VARCHAR(10) NOT NULL,
        Posted TINYINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL
    );

    INSERT #ContractsInOperations
    (
        opid,
        docid,
        doctypeid,
        Contract,
		DocCurrency,
        STATE,
        Amount,
        IsDebit,
        Mandat,
        Posted,
        AccountingDate,
        Date
    )
    SELECT mco.opid AS opid,
           mco.docid AS docid,
           mco.doctypeid AS doctypeid,
           --[ONEC-6603]
           ISNULL(op.ContractID, mco.ContractID) AS Contract,
		   mco.DocCurrency AS DocCurrency,
           mco.STATE AS State,
           op.AmountCurr AS Amount,
           1 AS IsDebit,
           mco.Mandat AS Mandat,
           mco.Posted AS Posted,
           mco.AccountingDate AS AccountingDate,
           mco.Date AS Date
    FROM #MultyContractOperations AS mco
        JOIN dbo.Operation_new AS op
            ON op.ID = mco.opid
               AND op.pNum = mco.pnum
    UNION ALL
    SELECT mco.id,
           mco.DocumentID,
           mco.DocTypeID,
           sf.ContractIdDeb,
		   mco.DocCurrency,
           mco.State,
           op.AmountCurr,
           1,
           mco.Mandat,
           mco.Posted,
           mco.AccountingDate,
           mco.Date
    FROM #CommonOperKeys AS mco
        JOIN dbo.Operation_new AS op
            ON op.ID = mco.id
               AND op.pNum = mco.pNum
        JOIN dbo.OperationSetOffBalance AS sf
            ON sf.ID = mco.id
    WHERE mco.DocTypeID IN ( @ZachetTrebovaniyPoBalansu )
          AND sf.ContractIdDeb IS NOT NULL

    OPTION (MAXDOP 8);
    CREATE STATISTICS opid_stat ON #ContractsInOperations (opid);

    CREATE STATISTICS Contract_Stat ON #ContractsInOperations (Contract);
    CREATE CLUSTERED INDEX OPID
    ON #ContractsInOperations (opid)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    CREATE NONCLUSTERED INDEX Contract
    ON #ContractsInOperations (Contract)
    INCLUDE (docid)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#ContractsInOperations',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #ExtContracts;
    CREATE TABLE #ExtContracts
    (
        ID BIGINT NOT NULL,
        CONTRACT BIGINT NULL INDEX CONTRACT CLUSTERED,
        DocTypeID BIGINT NOT NULL
    );
    INSERT #ExtContracts
    (
        ID,
        CONTRACT,
        DocTypeID		
	)
    SELECT D.ID AS ID,
           didc.ClientOrderID AS Contract,
           D.DocTypeID
    FROM #Docs AS D
        JOIN dbo.DocumentInternalDebtorChangePA AS didc
            ON didc.ID = D.ID
    WHERE D.DocTypeID = @SmenaDebitoraPA
    OPTION (MAXDOP 8);
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#ExtContracts',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #GMPDirectory;
    CREATE TABLE #GMPDirectory
    (
        GMPID BIGINT NOT NULL,
        Marketplace INT NOT NULL,
        Person BIGINT NOT NULL,
        Mandat BIGINT NOT NULL,
        Currency BIGINT NOT NULL,
        VAT NUMERIC(5, 2) NOT NULL INDEX Person CLUSTERED (Person)
    );
    INSERT #GMPDirectory
    (
        GMPID,
        Marketplace,
        Person,
        Mandat,
        Currency,
        VAT
    )
    SELECT gmp.ID AS GMPID,
           gmp.MarketPlaceID AS Marketplace,
           gmp.PersonID AS Person,
           gmp.DelimetrID AS Mandat,
           gmp.CurrencyID AS Currency,
           gmp.VAT AS VAT
    FROM dbo.GlobalMarketPlaceDirectory gmp;

    DROP TABLE IF EXISTS #GMP;
    CREATE TABLE #GMP
    (
        GMPID BIGINT NOT NULL,
        Marketplace INT NOT NULL,
        Person BIGINT NOT NULL,
        PayProp BIGINT NOT NULL,
        Mandat BIGINT NOT NULL,
        Currency BIGINT NOT NULL,
        VAT NUMERIC(5, 2) NOT NULL INDEX PayProp CLUSTERED (PayProp)
    );
    INSERT #GMP
    (
        GMPID,
        Marketplace,
        Person,
        PayProp,
        Mandat,
        Currency,
        VAT
    )
    SELECT gmp.GMPID AS GMPID,
           gmp.Marketplace AS MarketPlace,
           gmp.Person AS Person,
           pp.ID AS PayProp,
           gmp.Mandat AS Mandat,
           gmp.Currency AS Currency,
           gmp.VAT AS VAT
    FROM #GMPDirectory gmp
        JOIN dbo.PayProps AS pp
            ON pp.PersonID = gmp.Person;
    DROP TABLE IF EXISTS #GMPMain;
    CREATE TABLE #GMPMain
    (
        gmpid BIGINT NOT NULL,
        Marketplace INT NOT NULL,
        Person BIGINT NOT NULL,
        Mandat BIGINT NOT NULL,
        Currency BIGINT NOT NULL,
        VAT NUMERIC(5, 2) NOT NULL INDEX GMPID CLUSTERED (gmpid)
    );

    INSERT #GMPMain
    (
        gmpid,
        Marketplace,
        Person,
        Mandat,
        Currency,
        VAT
    )
    SELECT gmp.ID AS GMPID,
           gmp.MarketPlaceID AS MarketPlace,
           gmp.PersonID AS Person,
           gmp.DelimetrID AS Mandat,
           gmp.CurrencyID AS Currency,
           gmp.VAT AS VAT
    FROM dbo.GlobalMarketPlaceDirectory AS gmp
    WHERE gmp.MarketPlaceID = 1;
    DECLARE @AccountGroup_41_1 BIGINT = 31241000,     -- SELECT  dbo.ObjectGetBySysName('AccountGroup', '41.1')
            @AccountGroup_41_6 BIGINT = 769998604000, -- SELECT dbo.ObjectGetBySysName('AccountGroup', '41.6');
            @FakeOrganization BIGINT = 35842000;      --SELECT  dbo.ObjectGetBySysName('PersonLegal', 'FakeOrganization'); -- Промконтрактпроект
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#GMP',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #Partners;
    CREATE TABLE #Partners
    (
        DocID BIGINT NOT NULL,
        Contract BIGINT NULL,
		ContractCurrency BIGINT NOT NULL,
        PayProp BIGINT NULL,
        OwnerID BIGINT NOT NULL,
        SelfPayPropsID BIGINT NULL,
        IsDebit TINYINT NOT NULL,
		ISVGO TINYINT NOT null
    );
    INSERT #Partners
    (
        DocID,
        Contract,
		ContractCurrency,
        PayProp,
        OwnerID,
        SelfPayPropsID,
        IsDebit,
		ISVGO
    )
    SELECT D.ID AS DocID,
           C.ID AS Contract,
		   C.CurrencyID AS ContractCurrency,
           C.PayPropsID AS PayProp,
           C.PersonID AS OwnerID,
           C.SelfPayPropsID AS SelfPayPropsID,
           1 AS IsDebit,
		   D.IsVGO AS ISVGO
    FROM dbo.ContractReal AS C
        JOIN #Docs AS D
            ON D.ContractID = C.ID
    UNION
    SELECT D.ID,
           D.CONTRACT,
		   C.CurrencyID,
           C.PayPropsID AS PayProp,
           C.PersonID AS OwnerID,
           C.SelfPayPropsID,
           1 AS IsDebit,
		   0 AS ISVGO
    FROM #ExtContracts AS D
        JOIN dbo.ContractReal AS C
            ON C.ID = D.CONTRACT
    UNION ALL
    SELECT D.opid,
           C.ID,
		   C.CurrencyID,
           C.PayPropsID,
           C.PersonID,
           C.SelfPayPropsID,
           D.IsDebit,
		   0 
    FROM #ContractsInOperations AS D
        JOIN dbo.ContractReal AS C
            ON C.ID = D.Contract
    OPTION (MAXDOP 8);

    CREATE STATISTICS OwnerID_Stat ON #Partners (OwnerID, Contract);
    CREATE CLUSTERED INDEX OwnerID
    ON #Partners (
                     OwnerID,
                     Contract
                 )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    CREATE STATISTICS PayProp_Stat ON #Partners (PayProp);

    CREATE STATISTICS Contract_Stat ON #Partners (Contract);
    CREATE NONCLUSTERED INDEX PayProp
    ON #Partners (PayProp)
    INCLUDE (
                DocID,
                Contract,
                OwnerID,
                IsDebit
            )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    CREATE NONCLUSTERED INDEX Contract
    ON #Partners (Contract)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    DROP TABLE IF EXISTS #PartnersData;
    CREATE TABLE #PartnersData
    (
        DocID BIGINT NOT NULL,
        Contract BIGINT NOT NULL,
		ContractCurrency BIGINT NOT NULL,
        PayProp BIGINT NULL,
        OwnerID BIGINT NOT NULL,
        INN VARCHAR(100) NULL,
        KPP VARCHAR(100) NULL,
        Country BIGINT NULL,
        OwnerINN VARCHAR(100) NULL,
        OwnerKPP VARCHAR(100) NULL,
        Name VARCHAR(150) NULL,
        IsDebit TINYINT NOT NULL,
        ContractType BIGINT NOT NULL,
        CurrencyID BIGINT NOT NULL,
        GMP BIGINT NOT NULL,
        AccountID BIGINT NULL,
		ISVGO TINYINT NOT NULL
    );

    INSERT #PartnersData
    (
        DocID,
        Contract,
		ContractCurrency,
        PayProp,
        OwnerID,
        INN,
        KPP,
        Country,
        OwnerINN,
        OwnerKPP,
        Name,
        IsDebit,
        ContractType,
        CurrencyID,
        GMP,
        AccountID,
		ISVGO
    )
    SELECT Party.DocID AS DocID,
           Party.Contract AS Contract,
		   Party.ContractCurrency AS ContractCurrency,
           Party.PayProp AS PayProp,
           Party.OwnerID AS OwnerID,
           SUBSTRING(LTRIM(RTRIM(ISNULL(pp.INN, pers.INN))), 1, 100) AS INN,
           SUBSTRING(LTRIM(RTRIM(ISNULL(pp.KPP, pers.KPP))), 1, 20) AS KPP,
           ppi.CountryID AS Country,
           SUBSTRING(LTRIM(RTRIM(pers.INN)), 1, 100) AS OwnerINN,
           SUBSTRING(LTRIM(RTRIM(pers.KPP)), 1, 20) AS OwnerKPP,
           SUBSTRING(pers.ShortName, 1, 150) AS Name,
           Party.IsDebit AS IsDebit,
           o.ObjectTypeID AS ContractType,
           ISNULL(GMP.Currency, gmdef.Currency) AS CurrencyID,
           ISNULL(GMP.GMPID, gmdef.gmpid) AS GMP,
           Account.ID AS AccountID,
		   Party.ISVGO AS ISVGO
    FROM #Partners AS Party
        JOIN dbo.Person AS pers
            ON pers.ID = Party.OwnerID
        CROSS JOIN #GMPMain AS gmdef
        LEFT JOIN #GMP AS GMP
            ON GMP.PayProp = Party.SelfPayPropsID
        LEFT JOIN dbo.PayProps AS pp
            ON pp.ID = Party.PayProp
        LEFT JOIN dbo.PayPropsInter AS ppi
            ON ppi.ID = Party.PayProp
        JOIN dbo.Object AS o
            ON o.ID = Party.Contract
        LEFT JOIN dbo.Account AS Account
            ON Account.OwnerObjectID = Party.OwnerID
               AND Account.ObjectTypeID = 11008556172210 -- dbo.ObjectTypeGetBySysName('MarketplaceSellerAccount') 
               AND Account.ContractID = Party.Contract
               AND Account.StateID = 30032000 -- dbo.StateGetBySysName ('MarketplaceSellerAccount', 'Actual')
               AND Account.CurrencyID = ISNULL(GMP.Currency, gmdef.Currency)
    OPTION (MAXDOP 8);

    --DROP TABLE #Partners;
    CREATE STATISTICS DocID_Stat ON #PartnersData (DocID, AccountID);
    CREATE STATISTICS CountryID_Stat ON #PartnersData (Country);
    CREATE CLUSTERED INDEX DocID
    ON #PartnersData (
                         DocID,
                         AccountID
                     )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );

    IF @TurnMetrics > 0
    BEGIN
        SELECT 'Partners',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    -- Сертификаты
	DECLARE @OperationClientOrderPayment BIGINT =  13185740000;  -- dbo.ObjectTypeGetBySysName('OperationClientOrderPayment') 
	DECLARE @OperationCertificateTransferApiTypeId BIGINT = 11150171751560; -- dbo.ObjectTypeGetBySysName('OperationCertificateTransferAPI')
	DECLARE @OperCertTypes dbo.IDTable;
    INSERT @OperCertTypes
    (
        ID
    ) VALUES (@OperationClientOrderPayment)
	  INSERT @OperCertTypes
    (
        ID
    ) VALUES (@OperationCertificateTransferApiTypeId);
	DROP TABLE IF EXISTS #OperCertTypes;
	CREATE TABLE #OperCertTypes(ID BIGINT NOT NULL , pNum SMALLINT  NULL INDEX ID clustered  (ID) );
	INSERT #OperCertTypes
	(
	    ID,
	    pNum
	)
	SELECT opt.ID AS ID,
	opnum.pnum AS pNum
	FROM @OperCertTypes AS Opt
	   left JOIN dbo.pNumByOperationObjectTypeLst(
                           @OperCertTypes,
                                                 DATEADD(MONTH, -6, @BeginPeriod),
                                                 DATEADD(MONTH, 1, @EndPeriod)
                                             ) AS opnum
											 ON opnum.ObjectTypeID = Opt.ID


    DROP TABLE IF EXISTS #OperCertData;
    CREATE TABLE #OperCertData
    (
        NominalValue NUMERIC(15, 2) NOT NULL,
        ContractID BIGINT NOT NULL,
        DocID BIGINT NOT NULL,
        OperID BIGINT NOT NULL,
		pNum Smallint NOT NULL,
		ClientOrderPayment BIGINT NOT null
		INDEX ContracatId CLUSTERED (ContractID,ClientOrderPayment,pNum)
    );

    INSERT #OperCertData
    (
        NominalValue,
        ContractID,
        DocID,
        OperID,
		pNUm,
		ClientOrderPayment
    )
    SELECT op.Amount AS NominalValue,
           op.ContractID AS ContractID,
           COK.DocumentID,
           COK.id AS OperID,
		   Opertypes.pNum AS pNum,
		   Opertypes.ID AS ClientOrderPayment
    FROM #CommonOperKeys AS COK 
	JOIN dbo.Operation_new AS Op
	ON COK.id = op.id
	AND COK.pNum = op.pNum
	JOIN #OperCertTypes AS Opertypes
	ON Opertypes.ID = @OperationClientOrderPayment
	WHERE COK.DocTypeID IN ( @RealizatsiyaSertifikatovFizLitsam, @RealizatsiyaPopolnyayemogoSertifikata )
    OPTION (MAXDOP 8);
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#OperCertData',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DROP TABLE IF EXISTS #OperCertOrderPayment;
    CREATE TABLE #OperCertOrderPayment
    (
        id BIGINT NOT NULL,
		pNum SMALLINT NOT NULL,
        ContractID BIGINT NULL,
        DocID BIGINT NOT NULL,
        NominalValue NUMERIC(15, 2) NOT NULL INDEX id UNIQUE CLUSTERED (id)
    );
    INSERT #OperCertOrderPayment
    (
        id,
		pnum,
        ContractID,
        DocID,
        NominalValue
    )
    SELECT DISTINCT op.ID AS ID,
			op.pnum AS pNum,
           op.ContractID AS ContractID,
          -- opcd.DocID AS DocID,
		  op.ObjectTypeID,
           opcd.NominalValue AS NominalValue
    FROM dbo.Operation_New AS op
        JOIN #OperCertData AS opcd
            ON opcd.ContractID = op.ContractID
			AND opcd.ClientOrderPayment = op.ObjectTypeID
			AND opcd.pNum = op.pNum
    OPTION (MAXDOP 8);

    CREATE NONCLUSTERED INDEX DocID
    ON #OperCertOrderPayment (DocID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100
         );

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#OperCertOrderPayment',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DROP TABLE IF EXISTS #CertificateDiscount;
    CREATE TABLE #CertificateDiscount
    (
        ContractID BIGINT NOT NULL,
        Discount DECIMAL(15, 2) NOT NULL
    );

    INSERT #CertificateDiscount
    (
        ContractID,
        Discount
    )
    SELECT ocop.ContractID AS ContractID,
           SUM(op.Amount) AS Discount
    FROM dbo.Operation_New AS op
        JOIN #OperCertOrderPayment AS ocop
            ON ocop.id = op.ID
			AND ocop.pnum = op.pNum
    GROUP BY ocop.ContractID
    OPTION (MAXDOP 8);

    CREATE STATISTICS ContractID ON #CertificateDiscount (ContractID);

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#CertificateDiscount',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DROP TABLE IF EXISTS #CertificateRealization;
    CREATE TABLE #CertificateRealization
    (
        Mandat VARCHAR(15) NOT NULL,
        NominalValue DECIMAL(15, 2) NOT NULL,
        ID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        date DATETIME NULL,
        DocTypeID BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL,
        ContractID BIGINT NOT NULL
    );

    INSERT #CertificateRealization
    (
        Mandat,
        NominalValue,
        ID,
        AccountingDate,
        date,
        DocTypeID,
        Posted,
        dbo.State,
        ContractID
    )
    SELECT d.Mandat AS Mandat,
           SUM(ocd.NominalValue) AS NominalValue,
           d.ID AS ID,
           d.AccountingDate AS AccountingDate,
           d.Date AS Date,
           d.DocTypeID AS DocTypeID,
           d.Posted AS Posted,
           d.State AS State,
           ocd.ContractID AS ContractID
    FROM #Docs AS d
        JOIN #OperCertData AS ocd
            ON ocd.DocID = d.ID
			AND d.pnum = ocd.pnum
    GROUP BY d.Mandat,
             d.ID,
             d.AccountingDate,
             d.Date,
             d.DocTypeID,
             d.Posted,
             d.State,
             ocd.ContractID
    OPTION (MAXDOP 8);

    CREATE STATISTICS ContractID ON #CertificateRealization (ContractID);

    DROP TABLE #OperCertData;

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#CertificateRealization',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    --Акт передачи сертификатов  

    DROP TABLE IF EXISTS #NominalValueCFP;

    CREATE TABLE #NominalValueCFP
    (
        Mandat VARCHAR(15) NOT NULL,
        NominalValue NUMERIC(15, 2) NOT NULL,
        PayAmount NUMERIC(15, 2) NOT NULL,
        ID BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL INDEX ID CLUSTERED (ID)
    );
    INSERT #NominalValueCFP
    (
        Mandat,
        NominalValue,
        PayAmount,
        ID,
        DocTypeID,
        AccountingDate,
        Date,
        posted,
        State
    )
    SELECT d.Mandat AS Mandat,
           ISNULL(CertPurchase.NominalValue, 0) AS NominalValue,
           0 AS PayAmount,
           d.ID AS ID,
           d.DocTypeID AS DocTypeID,
           d.AccountingDate AS AccountingDate,
           d.Date AS Date,
           d.Posted AS Posted,
           d.State AS State
    FROM #Docs AS d
        JOIN dbo.Object AS o
            ON o.OwnerObjectID = d.ID
        JOIN dbo.CertificateForPurchase AS CertPurchase
            ON o.ID = CertPurchase.ID
    WHERE d.DocTypeID IN ( @AktPeredachiSertifikatov )
    OPTION (MAXDOP 8);

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#NominalValueCFP',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DROP TABLE IF EXISTS #NillValueCFP;
    CREATE TABLE #NillValueCFP
    (
        Mandat VARCHAR(15) NOT NULL,
        ID BIGINT NOT NULL,
		operType BIGINT  NULL,
		pNum SMALLINT  NULL,
        DocTypeID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL INDEX ID CLUSTERED (ID, operType, pNum)
    );
    INSERT #NillValueCFP
    (
        Mandat,
        ID,
		operType ,
		pnum,
        DocTypeID,
        AccountingDate,
        Date,
        posted,
        State
    )
    SELECT d.Mandat AS Mandat,
           d.ID AS ID,
		   OCT.ID AS OperType,
		   OCT.pNum AS pNum,
           d.DocTypeID AS DocTypeID,
           d.AccountingDate AS AccountingDate,
           d.Date AS Date,
           d.Posted AS Posted,
           d.State AS State
    FROM #Docs AS d
	LEFT JOIN #OperCertTypes AS OCT
	ON OCT.ID = @OperationCertificateTransferApiTypeId
        LEFT JOIN #NominalValueCFP AS NVCert
            ON d.ID = NVCert.ID
    WHERE d.DocTypeID IN ( @AktPeredachiSertifikatov )
          AND ISNULL(NVCert.NominalValue, 0) = 0
    OPTION (MAXDOP 8);

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#NillValueCFP',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;



    DROP TABLE IF EXISTS #CertOperations;
    CREATE TABLE #CertOperations
    (
        Mandat VARCHAR(15) NOT NULL,
        ID BIGINT NOT NULL,
        operid BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        date DATETIME NULL,
        Posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL INDEX operid CLUSTERED (operid)
    );
    INSERT #CertOperations
    (
        Mandat,
        ID,
        operid,
        DocTypeID,
        AccountingDate,
        date,
        Posted,
        State
    )
    SELECT d.Mandat AS Mandat,
           d.ID AS ID,
           CPO.ID AS operid,
           d.DocTypeID AS DocTypeID,
           d.AccountingDate AS AccountingDate,
           d.Date AS Date,
           d.posted AS Posted,
           d.State AS State
    FROM #NillValueCFP AS d
        JOIN dbo.Operation_New AS op
            ON op.DocumentID = d.ID
			AND op.ObjectTypeID = d.operType
			AND op.pnum = d.Pnum
        INNER JOIN dbo.Object AS CPO
            ON CPO.OwnerObjectID = op.ID
    OPTION (MAXDOP 8);
    DROP TABLE #NillValueCFP;

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#CertOperations',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DROP TABLE IF EXISTS #CertificateNominalValue;

    CREATE TABLE #CertificateNominalValue
    (
        Mandat VARCHAR(15) NOT NULL,
        NominalValue NUMERIC(15, 2) NOT NULL,
        ID BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        Posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL
    );
    INSERT #CertificateNominalValue
    (
        Mandat,
        NominalValue,
        ID,
        DocTypeID,
        AccountingDate,
        Date,
        Posted,
        State
    )
    SELECT d.Mandat AS Mandat,
           SUM(cfp.NominalValue) AS NominalValue,
           d.ID AS ID,
           d.DocTypeID AS DocTypeID,
           d.AccountingDate AS AccountingDate,
           d.date AS Date,
           d.Posted AS Posted,
           d.State AS State
    FROM #CertOperations AS d
        JOIN dbo.CertificateForPurchase AS cfp
            ON cfp.ID = d.operid
    GROUP BY d.Mandat,
             d.ID,
             d.DocTypeID,
             d.AccountingDate,
             d.date,
             d.Posted,
             d.State
    UNION ALL
    SELECT d.Mandat AS Mandat,
           SUM(d.NominalValue) AS NominalValue,
           d.ID AS ID,
           d.DocTypeID AS DocTypeID,
           d.AccountingDate AS AccountingDate,
           d.Date AS Date,
           d.posted AS Posted,
           d.State AS State
    FROM #NominalValueCFP AS d
        LEFT JOIN #CertOperations AS co
            ON co.ID = d.ID
    WHERE co.ID IS NULL
    GROUP BY d.Mandat,
             d.ID,
             d.DocTypeID,
             d.AccountingDate,
             d.Date,
             d.posted,
             d.State
    OPTION (MAXDOP 8);
    DROP TABLE #NominalValueCFP;
    DROP TABLE #CertOperations;

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#CertificateNominalValue',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
	-- Сертификаты конец
    DECLARE @NachisleniyeNaSchetSellera BIGINT
        = 11699192010030,                                                   -- dbo.ObjectTypeGetBySysName('EntrySellerInAggregate') 
            @SpisaniyeSoSchetaSellera BIGINT = 11699192010270,              -- dbo.ObjectTypeGetBySysName('EntrySellerOutAggregate')
            @NachisleniyeKompensatsiiNaSchetsellera BIGINT = 11699192010560 -- dbo.ObjectTypeGetBySysName('EntrySellerInCompensationAggregate')
    ;
    DROP TABLE IF EXISTS #ClearingOperations;
    CREATE TABLE #ClearingOperations
    (
        Mandat VARCHAR(15) NOT NULL,
		DocCurrency BIGINT NOT NULL,
		FactAmount NUMERIC(15, 2) NULL,
        Cost NUMERIC(15, 2) NOT NULL,
        ID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        DocTypeID BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL,
        OriginalDocTypeID BIGINT NULL,
        OperType BIGINT NOT NULL,
        EntryID BIGINT NULL,
        OriginalDocID BIGINT NOT NULL,
        IsMarketPlaceDir TINYINT NOT NULL
    );
    INSERT #ClearingOperations
    (
        Mandat,
		DocCurrency,
        FactAmount,
        Cost,
        ID,
        AccountingDate,
        Date,
        DocTypeID,
        Posted,
        State,
        OriginalDocTypeID,
        OperType,
        EntryID,
        OriginalDocID,
        IsMarketPlaceDir
    )
    SELECT op_keys.Mandat AS Mandat,
	op_keys.DocCurrency AS DocCurrency,
           CASE
               WHEN op_keys.DocTypeID IN ( @PlatezhCherezElectronniyKoshelek, @PlatezhnoyePorucheniyePoLocalnomuPA ) THEN
                   op.AmountCurr
               ELSE
                   op.Amount
           END * CASE
                     WHEN op_keys.DocTypeID = @VydachaSCHastichnoyOplatoy
                          AND op.ObjectTypeID = @OperationPartialPaymentRepaymentId THEN
                         -1
                     WHEN op_keys.DocTypeID = @VydachaSCHastichnoyOplatoy
                          AND op.ObjectTypeID = @OperationPartialPaymentOrder THEN
                         1
                     WHEN op_keys.DocTypeID = @VozratPlatezheyCHerezPA THEN
                         -1
                     WHEN op_keys.DocTypeID = @AktSpisaniyaTovarovUtilizirovannyhVDostavke THEN
                         0
                     ELSE
                         1
                 END AS Amount,
           CASE
               WHEN op_keys.DocTypeID IN ( @PlatezhCherezElectronniyKoshelek, @PlatezhnoyePorucheniyePoLocalnomuPA ) THEN
                   ISNULL(op.Amount, 0)
               ELSE
                   0
           END AS Cost,
           op_keys.DocumentID AS ID,
           op_keys.AccountingDate AS AccountingDate,
           op_keys.Date,
           op_keys.DocTypeID AS DocTypeID,
           op_keys.Posted AS Posted,
           op_keys.State AS State,
           op_keys.OriginalDocTypeID AS OriginalDocTypeID,
           op.ObjectTypeID AS OperType,
    NULL AS EntryID,
           op_keys.OriginalDocID AS OriginalDocID,
           op_keys.IsMarketPlaceDir AS IsMarketPlaceDir
    FROM #CommonOperKeys AS op_keys
        JOIN dbo.Operation_new AS op WITH (INDEX(Operation_new_ID_XPK)FORCESEEK)
            ON op.ID = op_keys.id
               AND op.pNum = op_keys.pNum
    WHERE op_keys.ClearingRO > 0
          AND op_keys.DocTypeID NOT IN ( @TrebovaniyeOPerevodeTretyemuLitsu, @ReyestrNachisleniyCRMPS,
                                         @RealizatsiyaTrevel, @TrebovaniyeOPerevodeTretyemuLitsu,
                                         @OtrazhenityVyruchkiSellera, @RealizatsiyaSertifikatovFizLitsam, @RealizatsiyaPopolnyayemogoSertifikata
                                       )
    UNION ALL
    SELECT op_keys.Mandat,
	op_keys.DocCurrency,
           op.AmountCurr - ISNULL(opTravel.VoucherValue, 0),
           0 AS Cost,
           op_keys.DocumentID AS ID,
           op_keys.AccountingDate AS AccountingDate,
           op_keys.Date,
           op_keys.DocTypeID AS DocTypeID,
           op_keys.Posted AS Posted,
           op_keys.State,
           op_keys.OriginalDocTypeID,
           op.ObjectTypeID,
           NULL,
           op_keys.OriginalDocID,
           0
    FROM #CommonOperKeys AS op_keys
        JOIN dbo.Operation_new AS op
            ON op.ID = op_keys.id
               AND op.pNum = op_keys.pNum
               AND op_keys.DocTypeID = @RealizatsiyaTrevel
        LEFT JOIN dbo.OperationTravelData AS opTravel WITH (INDEX(PK_OperationTravelData)FORCESEEK)
            ON opTravel.OperationID = op_keys.id
    UNION ALL
    SELECT op_keys.Mandat,
	op_keys.DocCurrency,
           op.AmountCurr,
           0 AS Cost,
           op_keys.DocumentID AS ID,
           op_keys.AccountingDate AS AccountingDate,
           op_keys.Date,
           op_keys.DocTypeID AS DocTypeID,
           op_keys.Posted AS Posted,
           op_keys.State,
           op_keys.OriginalDocTypeID,
           0,
           Entry.ID,
           op_keys.OriginalDocID,
           0
    FROM #CommonOperKeys AS op_keys
        JOIN dbo.Operation_new AS op
            ON op.ID = op_keys.id
               AND op.pNum = op_keys.pNum
        JOIN dbo.Entry_new AS Entry WITH (INDEX([IX_OperationID_EntryTypeId])FORCESEEK)
            ON Entry.OperationID = op_keys.id
               AND Entry.EntryTypeId = 11347066584020 -- select dbo.ObjectTypeGetBySysname('MarketplaceMKKTransferToThirdPersonEntry')
    WHERE op_keys.DocTypeID IN ( @TrebovaniyeOPerevodeTretyemuLitsu )
    UNION ALL
    SELECT op_keys.Mandat,
	op_keys.DocCurrency,
           op.Amount,
           0,
           op_keys.DocumentID,
           op_keys.AccountingDate,
           op_keys.Date,
           op_keys.DocTypeID,
           op_keys.Posted,
           op_keys.State,
           op_keys.OriginalDocTypeID,
           op.ObjectTypeID,
           NULL,
           op_keys.OriginalDocID,
           0
    FROM #CommonOperKeys AS op_keys
        JOIN dbo.Operation_new AS op
            ON op.ID = op_keys.id
               AND op.pNum = op_keys.pNum
               AND op_keys.DocTypeID IN ( @ReyestrNachisleniyCRMPS )
        LEFT JOIN dbo.ObjectDirectory AS od
            ON od.ObjectID = op_keys.DocumentID
        LEFT JOIN dbo.Object AS o
            ON o.ID = od.DirectoryID
               AND o.SysName = 'DirectoryGroupSettingsExceptDocument'
    WHERE o.ID IS NULL
    OPTION (MAXDOP 8);
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#ClearingOperations',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #ProxyBilling;
    CREATE TABLE #ProxyBilling
    (
        Mandat VARCHAR(15) NOT NULL,
		DocCurrency BIGINT NOT NULL,
        ID BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        DocTypeID BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        State NVARCHAR(50) NULL,
        OriginalDocTypeID BIGINT NULL,
        EntryID BIGINT NULL,
        OriginalDocID BIGINT NOT NULL,
        AccountID BIGINT NOT NULL,
        PERIOD int NOT NULL
    );
    INSERT #ProxyBilling
    (
        Mandat,
		DocCurrency,
        ID,
        AccountingDate,
        Date,
        DocTypeID,
        Posted,
        State,
        OriginalDocTypeID,
        EntryID,
        OriginalDocID,
        AccountID,
        Period
    )
    SELECT op_keys.Mandat,
			op_keys.DocCurrency,
           op_keys.DocumentID AS ID,
           op_keys.AccountingDate AS AccountingDate,
           op_keys.Date,
           op_keys.DocTypeID AS DocTypeID,
           op_keys.Posted AS Posted,
           op_keys.State,
           op_keys.OriginalDocTypeID,
           Proxy.EntryID,
           op_keys.OriginalDocID,
           Proxy.AccountID,
           Proxy.Period
    FROM #CommonOperKeys AS op_keys
        JOIN dbo.EntryProxy AS Proxy WITH (INDEX(EntryProxy_OperationID_XIF3)FORCESEEK)
            ON Proxy.OperationID = op_keys.id
    WHERE op_keys.DocTypeID IN ( @OtrazhenityVyruchkiSellera );
    CREATE STATISTICS EntryID_Stat ON #ProxyBilling (EntryID);
    CREATE CLUSTERED INDEX EntryID
    ON #ProxyBilling (EntryID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    CREATE STATISTICS DocID_Stat ON #ProxyBilling (ID, AccountID);
    CREATE NONCLUSTERED INDEX DocID
    ON #ProxyBilling (
                         ID,
                         AccountID
                     )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    DECLARE @DirectoryOperationSaleReturn BIGINT
        = dbo.ObjectGetBySysName('DirectorySystem', 'DirectoryOperationSaleReturn');
    DECLARE @DirectoryOperationSale BIGINT = dbo.ObjectGetBySysName('DirectorySystem', 'DirectoryOperationSale');

    DROP TABLE IF EXISTS #ComissionMarketPlace;
    CREATE TABLE #ComissionMarketPlace
    (
        ID BIGINT NOT NULL,
        Mandat VARCHAR(15) NOT NULL,
		DocCurrency BIGINT NOT NULL,
        state VARCHAR(50) NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NOT NULL,
        posted TINYINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        ObjectItemID BIGINT NULL,
        IsMarketPlaceDir TINYINT NOT NULL
    );
    INSERT #ComissionMarketPlace
    (
        ID,
        Mandat,
		DocCurrency,
        state,
        AccountingDate,
        Date,
        posted,
        DocTypeID,
        ObjectItemID,
        IsMarketPlaceDir
    )
    SELECT d.ID AS ID,
           d.Mandat AS Mandat,
		   d.DocCurrency AS DocCurrency, 
           d.State AS State,
           d.AccountingDate AS AccountingDate,
           d.Date AS Date,
           d.Posted AS posted,
           d.DocTypeID AS DocTypeID,
           oie.ID AS ObjectItemID,
           d.IsMarketPlaceDir AS IsMarketPlaceDir
    FROM #Docs AS d
        JOIN dbo.ObjectItemExemplar AS oie
            ON oie.ObjectID = d.ID
    WHERE d.DocTypeID = @KomissionnoyeVoznagrazhdeniye
    OPTION (MAXDOP 8);
    CREATE STATISTICS ObjectItemID_Stat
    ON #ComissionMarketPlace
    (
        ObjectItemID
    );
    CREATE CLUSTERED INDEX ObjectItemID
    ON #ComissionMarketPlace (ObjectItemID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Commissions',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #LinkOperation;
    CREATE TABLE #LinkOperation
    (
        id BIGINT NOT NULL,
        docid BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        oppostID BIGINT NOT NULL,
        INDEX ID UNIQUE CLUSTERED (id),
        Mandat VARCHAR(15) NOT NULL,
		DocCurrency BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        state VARCHAR(50) NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL
    );
    INSERT #LinkOperation
    (
        id,
        docid,
        DocTypeID,
        oppostID,
        Mandat,
		DocCurrency,
        Posted,
        state,
        AccountingDate,
        Date
    )
    SELECT DISTINCT
           LinkOp.ID AS ID,
           op.DocumentID AS docid,
           op.DocTypeID AS DocTypeID,
           LinkOp.LinkOperationId AS oppostID,
           op.Mandat AS Mandat,
		   op.DocCurrency AS DocCurrency,
           op.Posted AS Posted,
           op.State AS state,
           op.AccountingDate AS AccountingDate,
           op.Date AS Date
    FROM #CommonOperKeys AS op
        JOIN dbo.OperationLink_New AS LinkOp
            ON LinkOp.OperationId = op.id
    WHERE op.DocTypeID IN ( @Pretenziya, @AktSpisaniyaTovarovUtilizirovannyhVDostavke );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#LinkOperation',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #OperationLinkItem;
    CREATE TABLE #OperationLinkItem
    (
        id BIGINT NOT NULL,
        docid BIGINT NOT NULL,
        DocTypeID BIGINT NOT NULL,
        oppostID BIGINT NOT NULL INDEX ID CLUSTERED (id),
        Mandat VARCHAR(15) NOT NULL,
		DocCurrency BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        state VARCHAR(50) NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL
    );

    INSERT #OperationLinkItem
    (
        id,
        docid,
        DocTypeID,
        oppostID,
        Mandat,
		DocCurrency,
        Posted,
        state,
        AccountingDate,
        Date
    )
    SELECT LinkItem.ID AS id,
           linkop.docid AS docid,
           linkop.DocTypeID AS DocTypeID,
           linkop.oppostID AS oppostID,
           linkop.Mandat AS Mandat,
		   linkop.DocCurrency AS DocCurrency,
           linkop.Posted AS Posted,
           linkop.state AS State,
           linkop.AccountingDate AS AccountingDate,
           linkop.Date AS Date
    FROM #LinkOperation AS linkop
        JOIN dbo.OperationLinkItem AS LinkItem
            ON LinkItem.OperationLinkID = linkop.id;

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#OperationLinkItem',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #OperationLinkExemlar;
    CREATE TABLE #OperationLinkExemlar
    (
        id BIGINT NOT NULL,
        docid BIGINT NOT NULL,
        item_id BIGINT NOT NULL,
        oppostID BIGINT NOT NULL,
        ExemplarID BIGINT NOT NULL,
        Price NUMERIC(15, 2) NULL,
        INDEX id CLUSTERED (id),
        Mandat VARCHAR(15) NOT NULL,
		DocCurrency BIGINT NOT NULL, 
        Posted TINYINT NOT NULL,
        state VARCHAR(50) NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        DocTypeID BIGINT NOT NULL
    );

    INSERT #OperationLinkExemlar
    (
        id,
        docid,
        item_id,
        oppostID,
        ExemplarID,
        Price,
        Mandat,
		DocCurrency,
        Posted,
        state,
        AccountingDate,
        Date,
        DocTypeID
    )
    SELECT OperationLinkExemplar.ID AS id,
           OperationLinkItem.docid AS docid,
           OperationLinkItem.id AS item_id,
           OperationLinkItem.oppostID AS oppostID,
           OperationLinkExemplar.ExemplarID AS ExemplarID,
           LinkItem.Price AS Price,
           OperationLinkItem.Mandat AS Mandat,
		   OperationLinkItem.DocCurrency,
           OperationLinkItem.Posted AS Posted,
           OperationLinkItem.state AS state,
           OperationLinkItem.AccountingDate AS AccountingDate,
           OperationLinkItem.Date AS Date,
           OperationLinkItem.DocTypeID AS DocTypeID
    FROM #OperationLinkItem AS OperationLinkItem
        JOIN dbo.OperationLinkExemplar AS OperationLinkExemplar
            ON OperationLinkExemplar.OperationLinkItemID = OperationLinkItem.id
        JOIN dbo.OperationLinkItem AS LinkItem
            ON LinkItem.ID = OperationLinkItem.id;
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#OperationLinkExemlar',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #Operations;
    CREATE TABLE #Operations
    (
        operid BIGINT NOT NULL,
        id BIGINT NOT NULL,
        AccountingDate DATETIME NULL,
        Date DATETIME NULL,
        DocTypeID BIGINT NULL,
        OriginalDocID BIGINT NULL,
        Posted TINYINT NULL,
        Mandat VARCHAR(15) NULL,
		DocCurrency BIGINT NOT NULL,
        NDS NUMERIC(5, 2) NULL,
        Currency BIGINT NOT NULL,
        State NVARCHAR(50) NULL,
        pNum SMALLINT NULL,
        OriginalDocTypeID BIGINT NULL,
        OperationTypeID BIGINT NULL,
        OperAmountCurr NUMERIC(15, 2) NOT NULL,
        OperAmount NUMERIC(15, 2) NOT NULL,
        IsNewInbound TINYINT NOT NULL,
        DocGMP BIGINT NOT NULL,
        operDate DATETIME NULL,
        IsIngoingType TINYINT NOT NULL,
        IsOutGoingType TINYINT NOT NULL,
		ISVGO TINYINT NOT NULL,
        NoCosting TINYINT NOT NULL,
        OwnerObjectID BIGINT NULL
    );

    INSERT #Operations
    (
        operid,
        id,
        AccountingDate,
        Date,
        DocTypeID,
        OriginalDocID,
        Posted,
        Mandat,
		DocCurrency,
        NDS,
        Currency,
        State,
        pNum,
        OriginalDocTypeID,
        OperationTypeID,
        OperAmountCurr,
        OperAmount,
        IsNewInbound,
        DocGMP,
        IsIngoingType,
        IsOutGoingType,
		ISVGO,
        NoCosting,
        OwnerObjectID
    )
    SELECT Op.ID  AS OperID,
           OperKey.DocumentID AS ID,
           OperKey.AccountingDate AS AccountingDate,
           Op.Date AS Date,
           OperKey.DocTypeID AS DocTypeID,
           OperKey.OriginalDocID AS OriginalDocID,
           OperKey.Posted AS Posted,
           OperKey.Mandat AS Mandat,
		   OperKey.DocCurrency AS DocCurrency,
           OperKey.NDS AS NDS,
           OperKey.Currency AS Currency,
           OperKey.State AS State,
		   op.pNum  AS pNum,
           OperKey.OriginalDocTypeID AS OriginalDocTypeID,
           Op.ObjectTypeID AS OperationTypeID,
           ISNULL(Op.AmountCurr, 0) AS OperAmountCurr,
           CASE
               WHEN ISNULL(Op.Amount, 0) = 0 THEN
                   1
               ELSE
                   Op.Amount
           END AS OperAmount,
           0 AS IsNewInbound,
           OperKey.DocGMP AS DocGMP,
           OperKey.IsIngoingType AS IsIngoingType,
           OperKey.IsOutGoingType AS IsOutGoingType,
		   OperKey.ISVGO AS ISVGO,
           OperKey.NoCosting AS NoCosting,
           Op.OwnerObjectID AS OwnerObjectID
    FROM #CommonOperKeys AS OperKey
        JOIN dbo.Operation_new AS Op WITH (INDEX(Operation_new_ID_XPK)FORCESEEK)
            ON Op.ID = OperKey.id
               AND Op.pNum = OperKey.pNum
    WHERE OperKey.IsOutGoingType = 1
    UNION ALL
    SELECT D.ID AS OperID,
           D.ID AS ID,
           D.AccountingDate AS AccountingDate,
           D.Date AS Date,
           D.DocTypeID AS DocTypeID,
           D.OriginalDocID AS OriginalDocID,
           D.Posted AS Posted,
           D.Mandat AS Mandat,
		   D.DocCurrency AS DocCurrency,
           D.NDS AS NDS,
           D.Currency AS Currency,
           D.State AS State,
           D.pNum AS pNum,
           D.OriginalDocTypeID AS OriginalDocTypeID,
           NULL,
           0,
           0,
           D.IsNewInbound,
           D.gmp,
           D.IsIngoingType AS IsIngoingType,
           D.IsOutgoingType AS IsOutGoingType,
		   D.ISVGO,
           D.NoCosting AS NoCosting,
           NULL
    FROM #Docs AS D
    WHERE D.IsIngoingType = 1
    UNION ALL
    SELECT D.ID AS OperID,
           D.ID AS ID,
           D.AccountingDate AS AccountingDate,
           D.Date AS Date,
           D.DocTypeID AS DocTypeID,
           D.OriginalDocID AS OriginalDocID,
           D.Posted AS Posted,
           D.Mandat AS Mandat,
		   D.DocCurrency,
           D.NDS AS NDS,
           D.Currency AS Currency,
           D.State AS State,
           D.pNum AS pNum,
           D.OriginalDocTypeID,
           NULL,
           D.IsMarketPlaceDir,
           0,
           0,
           D.gmp,
           D.IsIngoingType AS IsIngoingType,
           D.IsOutgoingType AS IsOutGoingType,
		   D.ISVGO,
           D.NoCosting AS NoCosting,
           NULL
    FROM #Docs AS D
    WHERE D.DocTypeID = @KomissionnoyeVoznagrazhdeniye
          AND D.IsMarketPlaceDir = 0
    UNION ALL
    SELECT D.ID AS OperID,
           D.ID AS ID,
           D.AccountingDate AS AccountingDate,
           D.Date AS Date,
           D.DocTypeID AS DocTypeID,
           D.OriginalDocID AS OriginalDocID,
           D.Posted AS Posted,
           D.Mandat AS Mandat,
		   D.DocCurrency,
           D.NDS AS NDS,
           D.Currency AS Currency,
           D.State AS State,
           D.pNum AS pNum,
           D.OriginalDocTypeID,
           NULL,
           0,
           0,
           0,
           D.gmp,
           D.IsIngoingType AS IsIngoingType,
           D.IsOutgoingType AS IsOutGoingType,
		   D.ISVGO,
           D.NoCosting AS NoCosting,
           NULL
    FROM #Docs AS D
    WHERE D.DocTypeID IN ( @AktVypolnennyhRabotSelleraIskhodyashchij, @AktVypolnennyhRabotIskhodyashchij,
                           @AktVypolnennyhRabotAgentapoDostavke, @AktVypolnennyhRabotPoArendeVhodyaschiy,
                           @AktVypolnennyhRabotPoReklame, @AktVypolnennyhRabotPoReklameReklamnyKabinetPostavschika,
                           @AktNedostachiImporta, @CreditNote, @OtrazheniyeVruchkiSubagenta, @AktOBrake,
                           @AktONedostachi, @MarketPlaceKorrektirovkaSummUslug,
                           @aktVypolnennyhRabotaAgentapoDostavkeVhodyaschiyStorno
                         )
    OPTION (MAXDOP 8);
	
	 DROP TABLE #CommonOperKeys;
    CREATE STATISTICS OperId_Stat ON #Operations (operid, pNum);
    CREATE CLUSTERED INDEX OperId
    ON #Operations (
                       operid,
                       pNum
                   )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    CREATE STATISTICS OwnerObjectID_Stat ON #Operations (OwnerObjectID);
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Operations',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #Iposition;
    CREATE TABLE #Iposition
    (
        ipid BIGINT NOT NULL,
        operid BIGINT NULL,
        docid BIGINT NULL,
        AccountingDate DATETIME NULL,
        DocDate DATETIME NULL,
        DocTypeID BIGINT NULL,
        OriginalDocID BIGINT NULL,
        Posted TINYINT NULL,
        Mandat VARCHAR(15) NULL,
        NDS NUMERIC(5, 2) NULL,
        Currency BIGINT NOT NULL,
		DocCurrency BIGINT NOT NULL,
        State NVARCHAR(50) NULL,
        Coefficient INT NULL,
        pNum SMALLINT NULL,
        OriginalDocTypeID BIGINT NULL,
        ItemID BIGINT NULL,
        OperAmountCurr NUMERIC(15, 2) NOT NULL,
        OperAmount NUMERIC(15, 2) NOT NULL,
        IsNewInbound TINYINT NOT NULL,
        DocGMP BIGINT NULL,
        IsIngoingType TINYINT NOT NULL,
        IsOutGoingType TINYINT NOT NULL,
		ISVGO TINYINT NOT NULL, 
        NoCosting TINYINT NOT NULL
    );
    INSERT #Iposition
    (
        ipid,
        operid,
        docid,
        AccountingDate,
        DocDate,
        DocTypeID,
        OriginalDocID,
        Posted,
        Mandat,
        NDS,
        Currency,
		DocCurrency,
        State,
        Coefficient,
        pNum,
        OriginalDocTypeID,
        ItemID,
        OperAmountCurr,
        OperAmount,
        IsNewInbound,
        DocGMP,
        IsIngoingType,
        IsOutGoingType,
		ISVGO,
        NoCosting
    )
    SELECT ip.ID AS ipid,
           op.operid AS OperID,
           op.id AS DocID,
           op.AccountingDate AS AccountingDate,
           op.Date AS DocDate,
           op.DocTypeID AS DocTypeID,
           op.OriginalDocID AS OriginalDocID,
           op.Posted AS Posted,
           op.Mandat AS Mandat,
           op.NDS AS NDS,
           op.Currency AS Currency,
		   op.DocCurrency AS DocCurrency,
           op.State AS State,
           CASE
               WHEN op.DocTypeID IN ( @VozvratOtgruzhennyhTovarovFizLitsamKorrektirovka, @CreditNote,
                                      @NakladnayaVozvrataPostavschikuKorrektirovka, @FakticheskayaOplataSellerovStorno
                                    ) THEN
                   -1
               WHEN op.OriginalDocTypeID <> op.DocTypeID THEN
                   -1
               ELSE
                   1
           END AS Coefficient,
           ip.pNum AS pNum,
           op.OriginalDocTypeID AS OriginalDocTypeID,
           ip.ItemID AS ItemID,
           op.OperAmountCurr AS OperAmountCurr,
           op.OperAmount AS OperAmount,
           op.IsNewInbound AS IsNewInbound,
           op.DocGMP,
           op.IsIngoingType AS IsIngoingType,
           op.IsOutGoingType AS IsOutGoingType,
		   op.ISVGO AS ISVGO,
           op.NoCosting AS NoCosting
    FROM #Operations AS op
        JOIN dbo.ItemPosition_new AS ip WITH (INDEX([IX_ObjectID_pNum_ItemId])FORCESEEK)
            ON ip.ObjectID = op.operid
               AND ip.pNum = op.pNum
	
    OPTION (MAXDOP 8);
    DROP TABLE #Operations;

    CREATE STATISTICS IpId_Stat ON #Iposition (ipid, pNum);
    CREATE CLUSTERED INDEX IpId
    ON #Iposition (
                      ipid,
                      pNum
                  )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    CREATE STATISTICS Doctype_Stat ON #Iposition (DocTypeID, ipid);

    CREATE STATISTICS DocInfo
    ON #Iposition
    (
        OriginalDocID,
        AccountingDate,
        DocTypeID,
        Posted,
        Mandat,
        State,
        DocDate
    );



    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Iposition',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DROP TABLE IF EXISTS #Controlling_Preliminary;
    CREATE TABLE #Controlling_Preliminary
    (
        ipid BIGINT NOT NULL,
        pNum SMALLINT NOT NULL,
        Cost NUMERIC(15, 2) NOT NULL,
        ItemGroupCode VARCHAR(50) NULL,
        DocTypeID BIGINT NOT NULL,
        ContractID BIGINT NULL,
        ExemplarID BIGINT NOT NULL,
        DocGMP BIGINT NULL,
        AccountGroupDirID BIGINT NULL,
        NDS NUMERIC(4, 2) NULL,
        AccountingDate DATETIME NOT NULL,
        IsIngoingType TINYINT NOT NULL,
        OperID BIGINT NOT NULL,
        Mandat VARCHAR(15) NOT NULL,
        DocNDS NUMERIC(5, 2) NULL,
        DocCurrency BIGINT NOT NULL,
		FactIncomMoment DATETIME null
    );

    INSERT #Controlling_Preliminary
    (
        ipid,
        pNum,
        Cost,
        ItemGroupCode,
        DocTypeID,
        ContractID,
        ExemplarID,
        DocGMP,
        AccountGroupDirID,
        NDS,
        AccountingDate,
        IsIngoingType,
        OperID,
        Mandat,
        DocNDS,
        DocCurrency,
		FactIncomMoment
    )
    SELECT ip.ipid AS ipid,
           ip.pNum AS pNum,
           CASE
               WHEN ip.IsIngoingType = 1 THEN
                   0
               ELSE
                   ie.Price
           END AS Cost,
           CASE
               WHEN ie.ItemGroupCode = '00000017' THEN
                   '00000010'
               ELSE
                   ie.ItemGroupCode
           END AS ItemGroupCode,
           ip.DocTypeID AS DocTypeID,
           ie.ContractID AS ContractID,
           ie.ID AS ExemplarID,
           ip.DocGMP AS DocGMP,
           ie.AccountGroupDirID AS AccountGroupDirID,
           ie.NDS AS NDS,
           ISNULL(ip.DocDate, ip.AccountingDate) AS AccountingDate,
           ip.IsIngoingType AS IsIngoingType,
           ip.operid AS OperID,
           ip.Mandat AS Mandat,
           ip.NDS AS DocNDS,
           ip.Currency AS DocCurrency,
		   ie.FactIncomeMoment AS FactIncomMoment
    FROM #Iposition AS ip
        INNER JOIN dbo.ItemPositionExemplar AS ipe WITH (INDEX(ItemPositionExemplar_ItemPositionID_ItemExemplarID_XPK)FORCESEEK)
            ON ip.ipid = ipe.ItemPositionID
        JOIN dbo.ItemExemplar AS ie WITH (INDEX(ItemExemplar_ID_XPK)FORCESEEK)
            ON ipe.ItemExemplarID = ie.ID
    WHERE NOT (
                  ie.ItemGroupCode = '00000021'
                  AND ip.IsIngoingType = 1 -- CTI.ID IS NOT NULL
              )
          AND ip.NoCosting = 0
    OPTION (MAXDOP 8);
    CREATE STATISTICS Contract_Stat ON #Controlling_Preliminary (ContractID);
    CREATE CLUSTERED INDEX ContractID
    ON #Controlling_Preliminary (ContractID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Controlling_Preliminary',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #Controlling_SellerExemlars;
    CREATE TABLE #Controlling_SellerExemlars
    (
        ipid BIGINT NOT NULL,
        pNum SMALLINT NOT NULL,
        Cost NUMERIC(15, 2) NOT NULL,
        ItemGroupCode VARCHAR(50) NULL,
        DocTypeID BIGINT NOT NULL,
        ContractID BIGINT NULL,
        ExemplarID BIGINT NOT NULL,
        DocGMP BIGINT NULL,
        SelfPayPropsID BIGINT NULL,
        AccountGroupDirID BIGINT NULL,
        NDS NUMERIC(4, 2) NULL,
        AccountingDate DATETIME NOT NULL,
        Seller BIGINT NULL,
        IsIngoingType TINYINT NOT NULL,
        OperID BIGINT NOT NULL,
        Mandat VARCHAR(15) NOT NULL,
        DocNDS NUMERIC(5, 2) NULL,
        DocCurrency BIGINT NOT NULL,
		FactIncomMoment DATETIME null
    );
    INSERT #Controlling_SellerExemlars
    (
        ipid,
        pNum,
        Cost,
        ItemGroupCode,
        DocTypeID,
        ContractID,
        ExemplarID,
        DocGMP,
        SelfPayPropsID,
        AccountGroupDirID,
        NDS,
        AccountingDate,
        Seller,
        IsIngoingType,
        OperID,
        Mandat,
        DocNDS,
        DocCurrency,
		FactIncomMoment
    )
    SELECT CP.ipid,
           CP.pNum AS pNum,
           CP.Cost AS Cost,
           CP.ItemGroupCode,
           CP.DocTypeID,
           CP.ContractID,
           CP.ExemplarID,
           CP.DocGMP,
           CR.SelfPayPropsID,
           CP.AccountGroupDirID,
           CP.NDS,
           CP.AccountingDate AS AccountingDate,
           CR.PersonID AS Seller,
           CP.IsIngoingType AS IsIngoingType,
           CP.OperID AS OperID,
           CP.Mandat AS Mandat,
           CP.DocNDS AS DocNDS,
           CP.DocCurrency AS DocCurrency,
		   CP.FactIncomMoment AS FactIncomMoment
    FROM #Controlling_Preliminary AS CP
        LEFT JOIN dbo.ContractReal AS CR
            ON CR.ID = CP.ContractID
    OPTION (MAXDOP 8);
	DROP TABLE #Controlling_Preliminary;
    CREATE STATISTICS SelfPayPropsID_Stat
    ON #Controlling_SellerExemlars
    (
        SelfPayPropsID
    );
    CREATE CLUSTERED INDEX SelfPayPropsID
    ON #Controlling_SellerExemlars (SelfPayPropsID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Controlling_SellerExemlars',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #ControllingGMP;
    CREATE TABLE #ControllingGMP
    (
        ipid BIGINT NOT NULL,
        pnum SMALLINT NOT NULL,
        Cost NUMERIC(15, 2) NOT NULL,
        ItemGroupCode VARCHAR(50) NULL,
        DocTypeID BIGINT NOT NULL,
        ExemplarID BIGINT NOT NULL,
        DocGMP BIGINT NULL,
        AccountGroupDirID BIGINT NULL,
        NDS NUMERIC(4, 2) NULL,
        Seller BIGINT NULL,
        IsMarketplaceBBC TINYINT NOT NULL,
        AccountingDate DATETIME NOT NULL,
        SellerCurrency BIGINT NOT NULL,
        OperID BIGINT NOT NULL,
        Mandat VARCHAR(15) NOT NULL,
        DOCNDS NUMERIC(5, 2) NULL,
        DocCurrency BIGINT NOT NULL,
		FactIncomMoment datetime NULL
    );
    INSERT #ControllingGMP
    (
        ipid,
        pnum,
        Cost,
        ItemGroupCode,
        DocTypeID,
        ExemplarID,
        DocGMP,
        AccountGroupDirID,
        NDS,
        Seller,
        IsMarketplaceBBC,
        AccountingDate,
        SellerCurrency,
        OperID,
        Mandat,
        DOCNDS,
        DocCurrency,
		FactIncomMoment
    )
    SELECT CSE.ipid,
           CSE.pNum AS pnum,
           CSE.Cost AS Cost,
           CSE.ItemGroupCode,
           CSE.DocTypeID,
           CSE.ExemplarID,
           CSE.DocGMP,
           CSE.AccountGroupDirID,
           CSE.NDS,
           CSE.Seller AS Seller,
           CASE
               WHEN ISNULL(gmp.GMPID, gmpdef.gmpid) = ISNULL(CSE.DocGMP, gmpdef.gmpid) THEN
                   0
               WHEN CSE.DocTypeID IN ( @RealizatsiyaOtgruzhennyhTovarovYurLitsamRFBS,
                                       @RealizatsiyaOtgruzhennyhTovarovFizlitsamRFBS
                                     ) THEN
                   0
               WHEN CSE.IsIngoingType = 1 THEN
                   0
               ELSE
                   1
           END AS IsMarketplaceBBC,
           CSE.AccountingDate AS AccountingDate,
           ISNULL(gmp.Currency, gmpdef.Currency) AS SellerCurrency,
           CSE.OperID AS OperID,
           CSE.Mandat AS Mandat,
           CSE.DocNDS AS DocNDS,
           CSE.DocCurrency AS DocCurrency,
		   CSE.FactIncomMoment AS FactIncomMoment
    FROM #Controlling_SellerExemlars AS CSE
        CROSS JOIN #GMPMain AS gmpdef
        LEFT JOIN #GMP AS gmp WITH (INDEX(PayProp)FORCESEEK)
            ON gmp.PayProp = CSE.SelfPayPropsID
    OPTION (MAXDOP 8);
	DROP TABLE #Controlling_SellerExemlars;

CREATE NONCLUSTERED INDEX ExemplarID
    ON #ControllingGMP (
                           ExemplarID,
                           OperID
                           
                       )
    INCLUDE (
                ipid,
                Cost,
                ItemGroupCode,
                AccountGroupDirID,
                NDS,
                Seller,
                DOCNDS,
                DocCurrency,
                Mandat,
                AccountingDate,
                SellerCurrency,
				DocGMP
            )
    WHERE IsMarketplaceBBC = 1 
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    CREATE NONCLUSTERED INDEX Currncy
    ON #ControllingGMP (IsMarketplaceBBC,
                           SellerCurrency,
                           DocCurrency,
                           AccountingDate
                       )
    INCLUDE (
                ipid,
                Cost,
                ItemGroupCode,
                AccountGroupDirID,
                NDS,
                Seller,
                ExemplarID,
                Mandat,
                DocGMP,
                DOCNDS
            )
    WHERE IsMarketplaceBBC = 1 --OR DocGMP = 11524121507870 --OMK 
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#ControllingGMP',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #IGTSScope;
CREATE TABLE #IGTSScope
(
    ipid BIGINT NOT NULL,
    pnum SMALLINT NOT NULL,
    OperType BIGINT NOT NULL,
    Cost NUMERIC(15, 2) NOT NULL,
    ItemGroupCode VARCHAR(50) NULL,
    DocTypeID BIGINT NOT NULL,
    ExemplarID BIGINT NOT NULL,
    DocGMP BIGINT NULL,
    AccountGroupDirID BIGINT NULL,
    NDS NUMERIC(4, 2) NULL,
    Seller BIGINT NULL,
    IsMarketplaceBBC TINYINT NOT NULL,
    AccountingDate DATETIME NOT NULL,
    SellerCurrency BIGINT NOT NULL,
    OperID BIGINT NOT NULL,
    Mandat VARCHAR(15) NOT NULL,
    DOCNDS NUMERIC(5, 2) NULL,
    DocCurrency BIGINT NOT NULL
);
    INSERT #IGTSScope
(
    ipid,
    pnum,
    OperType,
    Cost,
    ItemGroupCode,
    DocTypeID,
    ExemplarID,
    DocGMP,
    AccountGroupDirID,
    NDS,
    Seller,
    IsMarketplaceBBC,
    AccountingDate,
    SellerCurrency,
    OperID,
    Mandat,
    DOCNDS,
    DocCurrency
)
SELECT CSE.ipid,
       OT.pNum AS pnum,
       OT.OperType AS OperType,
       CSE.Cost AS Cost,
       CSE.ItemGroupCode,
       CSE.DocTypeID,
       CSE.ExemplarID,
       CSE.DocGMP,
       CSE.AccountGroupDirID,
       CSE.NDS,
       CSE.Seller AS Seller,
       CSE.IsMarketplaceBBC AS IsMarketplaceBBC,
       CSE.AccountingDate AS AccountingDate,
       CSE.SellerCurrency AS SellerCurrency,
       CSE.OperID AS OperID,
       CSE.Mandat AS Mandat,
       CSE.DOCNDS AS DocNDS,
       CSE.DocCurrency AS DocCurrency
FROM #ControllingGMP AS CSE
    JOIN #OperTypes AS OT
        ON OT.id = @ZakupTovarovVGO 
           AND OT.OperType = @VnutriGruppovayaZakupka
           AND CSE.IsMarketplaceBBC = 1
UNION ALL
SELECT CSE.ipid,
       OT.pNum AS pnum,
       OT.OperType AS OperType,
       CSE.Cost AS Cost,
       CSE.ItemGroupCode,
       CSE.DocTypeID,
       CSE.ExemplarID,
       CSE.DocGMP,
       CSE.AccountGroupDirID,
       CSE.NDS,
       CSE.Seller AS Seller,
       CSE.IsMarketplaceBBC AS IsMarketplaceBBC,
       CSE.AccountingDate AS AccountingDate,
       CSE.SellerCurrency AS SellerCurrency,
       CSE.OperID AS OperID,
       CSE.Mandat AS Mandat,
       CSE.DOCNDS AS DocNDS,
       CSE.DocCurrency AS DocCurrency
FROM #ControllingGMP AS CSE
    JOIN #OperTypes AS OT
        ON OT.id = @NakladnayaRealizatsiiVGO3BC
           AND OT.OperType = @VnutriGruppovayaRealizatsiya
		   AND CSE.IsMarketplaceBBC = 1
           AND CSE.DocGMP = 11524121507870; --OMK 

    CREATE STATISTICS OperID_Stat ON #IGTSScope (OperID, OperType, pnum);
    CREATE CLUSTERED INDEX OperID
    ON #IGTSScope (
                      OperID,
                      OperType,
                      pnum
                  )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#IGTSScope',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #IGTSOperations;
    CREATE TABLE #IGTSOperations
    (
        IGTSOperId BIGINT NOT NULL,
        pNumIGTS SMALLINT NOT NULL,
        operID BIGINT NOT NULL,
		OperType BigInt NOT NULL,
        ExemplarID BIGINT NOT NULL,
        ipid BIGINT NOT NULL,
        Mandat VARCHAR(15) NOT NULL,
		DOCNDS NUMERIC(5,2) NULL
    );
    INSERT #IGTSOperations
    (
        IGTSOperId,
        pNumIGTS,
        operID,
		OperType,
        ExemplarID,
        ipid,
        Mandat,
		DOCNDS
    )
    SELECT op.ID AS IGTSOperId,
           op.pNum AS pNumIGTS,
           ip.OperID AS operid,
		   ip.OperType AS OperType,
		   ip.ExemplarID AS ExemplarID,
           ip.ipid AS ipid,
           ip.Mandat AS Mandat,
		   ip.DOCNDS AS DOCNDS
    FROM #IGTSScope AS ip
        INNER JOIN dbo.Operation_new AS op WITH (INDEX(IX_OwnerObjectID_ObjectTypeID_pNum))
            ON op.OwnerObjectID = ip.OperID
               AND op.ObjectTypeID = ip.OperType
              AND op.pNum = ip.pnum
			 ;
    CREATE STATISTICS IGTSOperId_stat
    ON #IGTSOperations
    (OperType,
        IGTSOperId,
        pNumIGTS
    );
	
    CREATE CLUSTERED INDEX IGTSOperId
    ON #IGTSOperations (Opertype,
                           IGTSOperId,
                           pNumIGTS
                       )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#IGTSOperations',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    /*DROP TABLE IF EXISTS #ReturnOpKeys;
CREATE TABLE #ReturnOpKeys (OwnerOperation BIGINT NOT NULL, operid BIGINT NOT NULL, OwnerpNum smallint NOT NULL);
INSERT #ReturnOpKeys
(
    OwnerOperation,
    operid,
	OwnerpNum
)
SELECT op.ID AS OwnerOperation,
igtsops.OperID AS operid,
op.pNum AS OwnerpNum
FROM #IGTSOperations AS igtsops
left JOIN dbo.Operation_New AS op WITH (INDEX (IX_OwnerObjectID_ObjectTypeID_pNum) )
ON op.OwnerObjectID = igtsops.IGTSOperId
--AND op.ObjecttypeID = 1031672468000 /*OperationAgentDeliveredToCustomer*/
--AND op.pNum = igtsops.pNumIGTS
SELECT * FROM #IGTSOperations WHERE IGTSOperId = 11722840420430*/

 DROP TABLE IF EXISTS #OMKRoubleIGTSOperations;
    CREATE TABLE #OMKRoubleIGTSOperations
    (
        Amount NUMERIC(15,2) NOT NULL,
        operID BIGINT NOT NULL,
        ExemplarID BIGINT NOT NULL,
        ipid BIGINT NOT NULL,
        Mandat VARCHAR(15) NOT NULL
    );
    INSERT #OMKRoubleIGTSOperations
    (
        Amount,
        operID,
        ExemplarID,
        ipid,
        Mandat
    )
    SELECT ISNULL(op.AmountCurr,0) AS Amount, 
           opIGTS.operID AS operID,
           opIGTS.ExemplarID AS ExemplarID,
           opIGTS.ipid AS ipid,
           opIGTS.Mandat AS Mandat
    FROM #IGTSOperations AS opIGTS
        JOIN dbo.Operation_new AS op
            ON op.id = opIGTS.IGTSOperId
               AND op.pNum = opIGTS.pNumIGTS
			   AND opIGTS.OperType = @VnutriGruppovayaRealizatsiya;
   /* CREATE STATISTICS ipidIGTS_stat ON #IpositionIGTS (ExemplarID, operID);
    CREATE CLUSTERED INDEX ipidIGTS
    ON #IpositionIGTS (
                          ExemplarID,
                          operID
                      )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );*/
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#IpositionIGTS',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #IpositionIGTS;
    CREATE TABLE #IpositionIGTS
    (
        ipidIGTS BIGINT NOT NULL,
        pNumIGTS SMALLINT NOT NULL,
        operID BIGINT NOT NULL,
        ExemplarID BIGINT NOT NULL,
        ipid BIGINT NOT NULL,
        Mandat VARCHAR(15) NOT NULL
    );
    INSERT #IpositionIGTS
    (
        ipidIGTS,
        pNumIGTS,
        operID,
        ExemplarID,
        ipid,
        Mandat
    )
    SELECT ip.ID AS ipidIGTS,
           ip.pNum AS pNumIGTS,
           opIGTS.operID AS operID,
           opIGTS.ExemplarID AS ExemplarID,
           opIGTS.ipid AS ipid,
           opIGTS.Mandat AS Mandat
    FROM #IGTSOperations AS opIGTS
        JOIN dbo.ItemPosition_new AS ip
            ON ip.ObjectID = opIGTS.IGTSOperId
               AND ip.pNum = opIGTS.pNumIGTS
			   AND opIGTS.OperType = @VnutriGruppovayaZakupka
    CREATE STATISTICS ipidIGTS_stat ON #IpositionIGTS (ipidIGTS, pNumIGTS);
    CREATE CLUSTERED INDEX ipidIGTS
    ON #IpositionIGTS (
                          ipidIGTS,
                          pNumIGTS
                      )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#IpositionIGTS',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    /*DROP TABLE IF EXISTS #ReturnOpDates;
CREATE TABLE #ReturnOpDates(opid BIGINT NOT NULL, AccountingDate DATETIME NULL);
INSERT #ReturnOpDates
(
    opid,
    AccountingDate
)
SELECT 
ROP.operID AS opid,
op.Date 
FROM #ReturnOpKeys AS ROP
JOIN dbo.Operation_New AS op
ON ROP.OwnerOperation = op.id
AND ROP.OwnerpNum = op.pNum
;
CREATE STATISTICS opid_Stat ON #ReturnOpDates(opid);
CREATE CLUSTERED INDEX opid ON #ReturnOpDates(opid)
WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
      ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
     );*/
    DROP TABLE IF EXISTS #ControllingIGTS_Preliminary;
    CREATE TABLE #ControllingIGTS_Preliminary
    (
        operID BIGINT NOT NULL,
        ExemplarID BIGINT NOT NULL,
        ipid BIGINT NOT NULL,
        Cost NUMERIC(15, 2) NOT NULL,
		COSTRUR NUMERIC(15,2) NOT NULL,
        Mandat VARCHAR(50) NOT NULL
    );
    INSERT #ControllingIGTS_Preliminary
    (
        operID,
        ExemplarID,
        ipid,
        Cost,
		CostRUR,
        Mandat
    )
SELECT T.operID AS OperID,
       ipe.ItemExemplarID AS ExemplarID,
       T.ipid AS ipid,
       ISNULL(IP.Price, 0) AS Cost,
       0 AS CostRUR,
       T.Mandat AS Mandat
FROM dbo.ItemPosition_new AS IP
    JOIN #IpositionIGTS AS T
        ON T.ipidIGTS = IP.ID
           AND T.pNumIGTS = IP.pNum
    JOIN dbo.ItemPositionExemplar ipe
        ON ipe.ItemPositionID = T.ipidIGTS
UNION ALL
SELECT OMKRUR.operID,
       OMKRUR.ExemplarID,
       OMKRUR.ipid,
       0,
       OMKRUR.Amount,
       OMKRUR.Mandat
FROM #OMKRoubleIGTSOperations AS OMKRUR;
   
   CREATE STATISTICS Exemplarid_stat
    ON #ControllingIGTS_Preliminary
    (
        ExemplarID,
        operID
    );
    DROP TABLE IF EXISTS #ControllingIGTS;
    CREATE TABLE #ControllingIGTS
    (
        operID BIGINT NOT NULL,
        ExemplarID BIGINT NOT NULL,
        Cost NUMERIC(15, 2) NOT NULL,
		CostRUR NUMERIC(15, 2) NOT NULL
    );
    INSERT #ControllingIGTS
    (
        operID,
        ExemplarID,
        Cost,
		COSTRUR
    )
    SELECT C.operID AS OperID,
           C.ExemplarID AS ExemplarID,
           MAX(C.Cost) AS Cost,
		   MAX(C.CostRUR) AS CostRUR
    FROM #ControllingIGTS_Preliminary AS C
    GROUP BY C.operID,
             C.ExemplarID,
             C.Mandat;
    CREATE STATISTICS Exemplarid_stat
    ON #ControllingIGTS
    (
        ExemplarID,
        operID
    );
    CREATE CLUSTERED INDEX Exemplarid
    ON #ControllingIGTS (
                            ExemplarID,
                            operID
                        )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    IF @TurnMetrics = 1
    BEGIN
        SELECT '#ControllingIGTS_Preliminary',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
	DECLARE @RUR BIGINT = 11441809; -- RUR
DROP TABLE IF EXISTS #Currencies;
CREATE TABLE #Currencies
(
    CurrencyFrom BIGINT NOT NULL,
    CurrencyTo BIGINT NOT NULL INDEX Currency CLUSTERED (CurrencyFrom)
);
INSERT #Currencies
(
    CurrencyFrom,
    CurrencyTo
)
SELECT c.SellerCurrency AS CurrencyFrom,
       c.DocCurrency AS CurrencyTo
FROM #ControllingGMP AS c
WHERE c.IsMarketplaceBBC = 1
UNION
SELECT @RUR,
       C.DocCurrency
	   FROM #ControllingGMP AS c
	   WHERE c.IsMarketplaceBBC = 1
OPTION (MAXDOP 8);
    DROP TABLE IF EXISTS #ExchangeRates;
    CREATE TABLE #ExchangeRates
    (
        CurrencyFrom BIGINT NOT NULL,
        CurrencyTo BIGINT NOT NULL,
        Date DATETIME NOT NULL,

        rate DECIMAL(30, 10) NOT NULL,
        Nominal INT NOT NULL INDEX Currency CLUSTERED (CurrencyFrom, CurrencyTo, Date)
    );
    INSERT #ExchangeRates
    (
        CurrencyFrom,
        CurrencyTo,
        Date,
   
        rate,
        Nominal
    )
    SELECT C.CurrencyFrom AS CurrencyFrom,
           C.CurrencyTo AS CurrencyTo,
           ISNULL(CER.Date, @BeginPeriod) AS Date,
          
           CASE
               WHEN C.CurrencyTo = C.CurrencyFrom THEN
                   1
               ELSE
                   CER.Rate
           END AS Rate,
           CASE
               WHEN C.CurrencyTo = C.CurrencyFrom THEN
                   1
               ELSE
                   CER.Nominal
           END AS Nominal
    FROM #Currencies AS C
        LEFT JOIN dbo.CurrencyExchangeRate AS CER
            ON CER.CurrencyIDFrom = C.CurrencyTo
               AND CER.CurrencyIDTo = C.CurrencyFrom
               AND CER.Date
               BETWEEN DATEADD(MONTH, -1, @BeginPeriod) AND DATEADD(MONTH, 1, @EndPeriod)
    -- BETWEEN  @BeginPeriod AND @EndPeriod
    OPTION (MAXDOP 8);
    DROP TABLE IF EXISTS #CurrencyRatesIntervals;
    CREATE TABLE #CurrencyRatesIntervals
    (
        CurrencyFrom BIGINT NOT NULL,
        CurrencyTo BIGINT NOT NULL,
        Datefrom DATETIME NOT NULL,
        DateTo DATETIME NOT NULL,
        Rate DECIMAL(30, 10) NOT NULL,
        Nominal INT NOT NULL INDEX Currency CLUSTERED (CurrencyFrom, CurrencyTo, Datefrom, DateTo)
    );
    INSERT #CurrencyRatesIntervals
    (
        CurrencyFrom,
        CurrencyTo,
        Datefrom,
        DateTo,
        Rate,
        Nominal
    )
    SELECT er.CurrencyFrom AS CurrencyFrom,
           er.CurrencyTo AS CurrencyTo,      
           er.Date AS DateFrom,
           ISNULL(MIN(DATEADD(SECOND, -1, erLast.Date)), '39991231') AS DateTo,
           MAX(er.rate) AS Rate,
           CASE WHEN ISNULL(MAX(er.Nominal),0) = 0 THEN 1 ELSE MAX(er.Nominal) END AS Nominal
    FROM #ExchangeRates AS er
        LEFT JOIN #ExchangeRates AS erLast
            ON er.CurrencyFrom = erLast.CurrencyFrom
               AND er.CurrencyTo = erLast.CurrencyTo
               AND er.Date < erLast.Date
    GROUP BY er.CurrencyFrom,
             er.CurrencyTo,
             er.Date
    OPTION (MAXDOP 8);
    --DROP TABLE #ExchangeRates;
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#CurrencyRates',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    CREATE STATISTICS ipid_stat
    ON #ControllingGMP
    (
        ipid,
        ItemGroupCode
    )
    WHERE IsMarketplaceBBC = 0;

    DROP TABLE IF EXISTS #Controlling;
    CREATE TABLE #Controlling
    (
        Ipid BIGINT NOT NULL,
        Cost NUMERIC(15, 2)  NULL,
		CostRUR NUMERIC(15, 2)  NULL,
        ItemGroupCode VARCHAR(50) NULL,
        Qty NUMERIC(15, 0) NULL,
        IsmarketPlaceBBC TINYINT NOT NULL
    );
    INSERT #Controlling
    (
        Ipid,
        Cost,
		CostRUR,
        ItemGroupCode,
        Qty,
        IsmarketPlaceBBC
    )
    SELECT c.ipid AS ipid,
           SUM(   CASE
                      WHEN c.AccountGroupDirID IN ( @AccountGroup_41_1, @AccountGroup_41_6 )
                           OR c.Seller = @FakeOrganization THEN
                          ROUND((c.Cost * 100.00) / (100.00 + ISNULL(c.NDS, 0.00)), 2)
                      ELSE
                          c.Cost
                  END
              ) AS Cost,
			NULL AS CostRUR,
           c.ItemGroupCode AS ItemGroupCode,
           COUNT(ipid) AS Qty,
           0 AS IsmarketPlaceBBC
    FROM #ControllingGMP AS c
    WHERE c.IsMarketplaceBBC = 0
    GROUP BY c.ipid,
             c.ItemGroupCode
    OPTION (MAXDOP 8);


    DROP TABLE IF EXISTS #CostNewKeys;
    CREATE TABLE #CostNewKeys
    (
        CostNewID BIGINT NOT NULL,
        ExemplarID BIGINT NOT NULL,
        DocGMP BIGINT NOT NULL
    );
    INSERT #CostNewKeys
    (
        CostNewID,
        ExemplarID,
        DocGMP
    )
    SELECT CostNew.ID AS CostNewID,
           C.ExemplarID AS ExemplarID,
           C.DocGMP AS DocGMP
    FROM #ControllingGMP AS C
        JOIN dbo.ItemExemplarCost_New AS CostNew
            ON CostNew.ExemplarID = C.ExemplarID
               AND C.IsMarketplaceBBC = 1
               AND CostNew.MPID = C.DocGMP;
    CREATE STATISTICS CostNewID_Stat ON #CostNewKeys (CostNewID);
    CREATE CLUSTERED INDEX CostNewID
    ON #CostNewKeys (CostNewID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    DROP TABLE IF EXISTS #CostNew;
    CREATE TABLE #CostNew
    (
        Price NUMERIC(15, 2) NOT NULL,
        ExemplarID BIGINT NOT NULL,
        DocGMP BIGINT NOT NULL
    );
    INSERT #CostNew
    (
        Price,
        ExemplarID,
        DocGMP
    )
    SELECT MIN(ISNULL(iec.Price, 0)) AS Price,
           CostNew.ExemplarID AS ExemplarID,
           CostNew.DocGMP AS DocGMP
    FROM #CostNewKeys AS CostNew
        JOIN dbo.ItemExemplarCost_New AS iec
            ON iec.ID = CostNew.CostNewID
    GROUP BY CostNew.ExemplarID,
             CostNew.DocGMP;
    CREATE STATISTICS ExemplarID_Stat ON #CostNew (ExemplarID, DocGMP);
    CREATE CLUSTERED INDEX ExemplarID
    ON #CostNew (
                    ExemplarID,
                    DocGMP
                )
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );
    --Truncate TABLE 	#Controlling
    INSERT #Controlling
    (
        Ipid,
        Cost,
		COSTRUR,
        ItemGroupCode,
        Qty,
        IsmarketPlaceBBC
    )
  SELECT c.ipid AS ipid,
       SUM(   COALESCE(CIGTS.Cost, CostNew.Price, ISNULL(c.Cost, 0) * Rates.Rate / Rates.Nominal)
              / (1 + CASE
                         WHEN CIGTS.ExemplarID IS NULL THEN
                             ISNULL(c.NDS / 100, 0.00)
                         ELSE
                             c.DOCNDS / 100
                     END
                )
          ) AS Cost,
       SUM(   CASE
                  WHEN ISNULL(CIGTS.CostRUR,0) = 0 THEN
                      ISNULL(c.Cost, 0) * RURRates.Rate / RURRates.Nominal
                  ELSE
                      CIGTS.CostRUR
              END / (1 + CASE
                             WHEN CIGTS.ExemplarID IS NULL THEN
                                 ISNULL(c.NDS / 100, 0.00)
                             ELSE
                                 c.DOCNDS / 100
                         END
                    )
          ) AS CostRUR,
       c.ItemGroupCode AS ItemGroupCode,
       COUNT(c.ipid) AS Qty,
       1 AS IsmarketPlaceBBC
FROM #ControllingGMP AS c
    LEFT JOIN #CostNew AS CostNew WITH (INDEX(ExemplarID)FORCESEEK)
        ON CostNew.ExemplarID = c.ExemplarID
           AND c.IsMarketplaceBBC = 1
           AND CostNew.DocGMP = c.DocGMP
    LEFT JOIN #CurrencyRatesIntervals AS Rates WITH (INDEX(Currency)FORCESEEK)
        ON Rates.CurrencyFrom = c.SellerCurrency
           AND Rates.CurrencyTo = c.DocCurrency
           AND c.AccountingDate
           BETWEEN Rates.Datefrom AND Rates.DateTo
           AND c.IsMarketplaceBBC = 1
    LEFT JOIN #CurrencyRatesIntervals AS RURRates WITH (INDEX(Currency)FORCESEEK)
        ON RURRates.CurrencyFrom = c.SellerCurrency
           AND RURRates.CurrencyTo = c.DocCurrency
           AND c.FactIncomMoment
           BETWEEN RURRates.Datefrom AND RURRates.DateTo
           AND c.IsMarketplaceBBC = 1
    LEFT JOIN #ControllingIGTS AS CIGTS WITH (INDEX(ExemplarID)FORCESEEK)
        ON CIGTS.ExemplarID = c.ExemplarID
           AND CIGTS.operID = c.OperID
           AND c.IsMarketplaceBBC = 1
WHERE c.IsMarketplaceBBC = 1
GROUP BY c.ipid,
         c.ItemGroupCode
    OPTION (MAXDOP 8);
    CREATE STATISTICS ipid_stat ON #Controlling (Ipid);
    CREATE CLUSTERED INDEX ipid
    ON #Controlling (Ipid)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );

    /*DROP TABLE #ControllingIGTS;
    DROP TABLE #ControllingIGTS_Preliminary;
    DROP TABLE #ControllingGMP;*/

    --SELECT * FROM #ResultSELECT * FROM #CostNew WHERE ExemplarID = 11651189565920
  /* SELECT * FROM #Iposition AS I WHERE I.ipid = 60000494075172
SELECT * FROM #ControllingGmp WHERE ipid = 220000547044699
SELECT * FROM ItemExemplarCost_New WHERE ExemplarID = 11694775269010
SELECT * FROM #Controlling WHERE ipid = 220000547044699
SELECT * FROM #CurrencyRatesIntervals ORDER BY currencyfrom, currencyto, datefrom, dateto
--SELECT SUM(Cost ) FROM #Controlling WHERE IsmarketPlaceBBC = 1

--Drop table #ControllingGMP;
SELECT * FROM #ControllingGMP WHERE ipid = 60000494075172
SELECT * FROM #ControllingIGTS_Preliminary AS CIP WHERE CIP.ExemplarID = 11694775269010
DROP TABLE IF EXISTS ##t2
SELECT c.ipid, c.cost*ip.Coefficient AS Cost, ip.operid,  c.IsMarketplacebbc 
INTO ##t2 
SELECT * 
FROM #iposition ip JOIN #ControllingGMP c ON ip.ipid = c.ipid
--SELECT * FROM ##t2
AND ip.ipid = 220000547044699
--WHERE docid = 11718552176350
SELECT * FROM ##t2 WHERE ipid = 20000493140392
SELECT * FROM ItemExemplarCost_New WHERE ExemplarID = 11711120620170
DROP TABLE IF EXISTS ##m
SELECT * INTO ##m2 FROM #main m WHERE m.id = 11718552176350

SELECT
SUM(ISNULL(ipdata.Price, 0)* (T.Coefficient * ISNULL(C.Qty, ISNULL(ipdata.FactQty, 0) - ISNULL(ipdata.ClaimQty, 0)))) AS FactAmount,
SUM( ISNULL(C.Cost, 0) * T.Coefficient * CASE WHEN C.IsmarketPlaceBBC = 1 THEN c.Qty ELSE 1 END) AS cost

FROM #Iposition AS T
LEFT JOIN #NoReturnDelivery AS NRD WITH (INDEX(ipid) FORCESEEK)
        ON NRD.ipid = T.ipid
           AND NRD.pnum = T.pNum
		   
    INNER JOIN dbo.ItemPosition_new AS ipdata WITH (INDEX([PK_ItemPosition_ID_pNum])FORCESEEK)
        ON ipdata.ID = T.ipid
           AND ipdata.pNum = T.pNum
    LEFT JOIN #Controlling AS C WITH (INDEX(ipid)FORCESEEK)
        ON C.Ipid = T.ipid 
    LEFT JOIN #Subconto AS Subconto WITH (INDEX(ipid)FORCESEEK)
        ON Subconto.ipid = T.ipid AND 1 =0
WHERE 
  NRD.ipid IS NULL AND T.docid = 11718552176350
SELECT SUM(FactAmount) FROM ##M
UNION ALL
SELECT - SUM(FactAmount) FROM ##M2
SELECT COUNT(*), SUM(Qty), SUM(Cost) FROM ##t
UNION ALL 
SELECT COUNT(*) , SUM(Qty), SUM(Cost) FROM ##t2
SELECT 
T.ipid,  SUM(T.cost), SUM(q1), SUM(q2)
FROM 
(SELECT ipid ,  cost, cost AS q1, 0 AS q2
FROM ##t2
UNION ALL
SELECT PositionId,  -cost, 0, cost
FROM ##t ) T
GROUP BY T.ipid
HAVING SUM(T.cost) <> 0
ORDER BY 2 DESC
SELECT * FROM #Controlling WHERE ipid = 260000501105386*/
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Controlling',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #Items;
    CREATE TABLE #Items
    (
        itemid BIGINT NOT NULL,
        ipid BIGINT NOT NULL,
        pNum SMALLINT NOT NULL,
        operID BIGINT NULL,
        DocTypeID BIGINT NOT NULL
    );
    INSERT #Items
    (
        itemid,
        ipid,
        pNum,
        operID,
        DocTypeID
    )
    SELECT I.ItemID AS itemid,
           I.ipid AS ipid,
           I.pNum AS pNum,
           I.operid AS OperID,
           I.DocTypeID AS DocTypeID
    FROM #Iposition AS I
    WHERE I.DocTypeID IN ( @AktVypolnennyhRabotSelleraIskhodyashchij,
                           @AktVypolnennyhRabotPoReklameReklamnyKabinetPostavschika,
                           @VozvratOtgruzhennyhTovarovFizLitsam, @VozvratOtgruzhennyhTovarovYUrLitsam,
                           @MarketPlaceRealizatsiyaTSifrovyhTovarov
                         )
          AND I.ItemID IS NOT NULL
    OPTION (MAXDOP 8);
    CREATE STATISTICS DocType_Stat ON #Items (DocTypeID, itemid);
    CREATE STATISTICS item_stat ON #Items (itemid);
    CREATE CLUSTERED INDEX Item
    ON #Items (itemid)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, MAXDOP = 8
         );

    DROP TABLE IF EXISTS #ItemDelivery;
    CREATE TABLE #ItemDelivery
    (
        OperID BIGINT NOT NULL,
        ipid BIGINT NOT NULL,
        pnum SMALLINT NOT NULL INDEX OperID CLUSTERED (OperID)
    );
    INSERT #ItemDelivery
    (
        OperID,
        ipid,
        pnum
    )
    SELECT T.operID AS OperID,
           T.ipid AS ipid,
           T.pNum AS pnum
    FROM dbo.ItemDelivery AS Delivery
        JOIN #Items AS T
            ON T.itemid = Delivery.ID
    WHERE T.DocTypeID IN ( @VozvratOtgruzhennyhTovarovFizLitsam, @VozvratOtgruzhennyhTovarovYUrLitsam,
                           @MarketPlaceRealizatsiyaTSifrovyhTovarov
                         )
    OPTION (MAXDOP 8);

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#ItemDelivery',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DECLARE @OperationSaleDeliveryAdmission BIGINT = dbo.ObjectTypeGetBySysName('OperationSaleDeliveryAdmission');
    DECLARE @OperationAgentDeliveredToCustomer BIGINT
        = dbo.ObjectTypeGetBySysName('OperationAgentDeliveredToCustomer');
    DROP TABLE IF EXISTS #OperationSalesDeliveryAdmissionKeys;
    CREATE TABLE #OperationSalesDeliveryAdmissionKeys
    (
        ipid BIGINT NOT NULL,
        ObjectID BIGINT NOT NULL,
        pnum SMALLINT NOT NULL INDEX ObjectID CLUSTERED (ObjectID)
    );
    INSERT #OperationSalesDeliveryAdmissionKeys
    (
        ipid,
        ObjectID,
        pnum
    )
    SELECT NRD.ipid AS ipid,
           o.ID AS ObjectID,
           NRD.pnum AS pnum
    FROM #ItemDelivery AS NRD
        JOIN dbo.Object AS o
            ON o.OwnerObjectID = NRD.OperID
    OPTION (MAXDOP 8);
    DROP TABLE IF EXISTS #PreNoReturnDelivery;
    CREATE TABLE #PreNoReturnDelivery
    (
        ipid BIGINT NOT NULL,
        pnum SMALLINT NOT NULL
    );
    INSERT #PreNoReturnDelivery
    (
        ipid,
        pnum
    )
    SELECT NRD.ipid AS Ipid,
           NRD.pnum AS pNum
    FROM #OperationSalesDeliveryAdmissionKeys AS NRD
        JOIN dbo.Object AS O
            ON O.ID = NRD.ObjectID
               AND O.ObjectTypeID IN ( @OperationSaleDeliveryAdmission )
    OPTION (MAXDOP 8);
    DROP TABLE IF EXISTS #DeliveredToCustomerOwners_1;
    CREATE TABLE #DeliveredToCustomerOwners_1
    (
        ipid BIGINT NOT NULL,
        OwnerID BIGINT NOT NULL,
        pnum SMALLINT NOT NULL INDEX OwnerID CLUSTERED (OwnerID)
    );
    INSERT #DeliveredToCustomerOwners_1
    (
        ipid,
        OwnerID,
        pnum
    )
    SELECT NRD.ipid AS ipid,
           o.OwnerObjectID AS OwnerID,
           NRD.pnum AS pnum
    FROM #ItemDelivery AS NRD
        JOIN dbo.Object AS o
            ON o.ID = NRD.OperID
    OPTION (MAXDOP 8);
    DROP TABLE IF EXISTS #DeliveredToCustomerOwners_2;
    CREATE TABLE #DeliveredToCustomerOwners_2
    (
        DeliveryType BIGINT NOT NULL,
        ipid BIGINT NOT NULL,
        ObjectID BIGINT NOT NULL,
        pnum SMALLINT NOT NULL INDEX DeliveryType_ObjectID CLUSTERED (ObjectID)
    );
    INSERT #DeliveredToCustomerOwners_2
    (
        DeliveryType,
        ipid,
        ObjectID,
        pnum
    )
    SELECT @OperationAgentDeliveredToCustomer AS DeliveryType,
           NRD.ipid AS ipid,
           o.ID AS OwnerID,
           NRD.pnum AS pnum
    FROM #DeliveredToCustomerOwners_1 AS NRD
        JOIN dbo.Object AS o
            ON o.OwnerObjectID = NRD.OwnerID
    --Where o.OwnerObjectID Is not NULL
    OPTION (MAXDOP 8);
    INSERT #PreNoReturnDelivery
    (
        ipid,
        pnum
    )
    SELECT NRD.ipid AS Ipid,
           NRD.pnum AS pNum
    FROM #DeliveredToCustomerOwners_2 AS NRD
        JOIN dbo.Object AS O WITH (INDEX(Object_ID_XPK)FORCESEEK)
            ON O.ID = NRD.ObjectID
               AND O.ObjectTypeID IN ( @OperationAgentDeliveredToCustomer )
    OPTION (MAXDOP 8);

    CREATE STATISTICS Id_Stat ON #PreNoReturnDelivery (ipid);
    DROP TABLE IF EXISTS #NoReturnDelivery;
    CREATE TABLE #NoReturnDelivery
    (
        ipid BIGINT NOT NULL,
        pnum SMALLINT NOT NULL INDEX IPID UNIQUE CLUSTERED (ipid, pnum)
    );
    INSERT #NoReturnDelivery
    (
        ipid,
        pnum
    )
    SELECT NRD.ipid AS Ipid,
           NRD.pnum AS pNum
    FROM #PreNoReturnDelivery AS NRD
    GROUP BY Ipid,
             pNum
    OPTION (MAXDOP 16);
    DROP TABLE #PreNoReturnDelivery;
    DROP TABLE #OperationSalesDeliveryAdmissionKeys;
    DROP TABLE #DeliveredToCustomerOwners_2;
    DROP TABLE #DeliveredToCustomerOwners_1;


    IF @TurnMetrics > 0
    BEGIN
        SELECT '#NoReturnDelivery',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DROP TABLE IF EXISTS #Subconto;
    CREATE TABLE #Subconto
    (
        ipid BIGINT NOT NULL,
        ItemCode VARCHAR(50) NOT NULL
    );
    INSERT #Subconto
    (
        ipid,
        ItemCode
    )
    SELECT Items.ipid AS ipid,
           CONVERT(VARCHAR(50), ISNULL(ObjSrc.SourceKey, '0000005734')) AS ItemCode
    FROM #Items AS Items
        JOIN dbo.ObjectSource AS ObjSrc
            ON ObjSrc.ObjectID = Items.itemid
               AND ObjSrc.TableName = 'Номенклатура'
               AND ObjSrc.SourceID = 1025760280000 --buh8
    WHERE Items.DocTypeID IN ( @AktVypolnennyhRabotSelleraIskhodyashchij,
                               @AktVypolnennyhRabotPoReklameReklamnyKabinetPostavschika
                             )
    OPTION (MAXDOP 8);
    CREATE STATISTICS ipid_stat ON #Subconto (ipid);
    CREATE CLUSTERED INDEX ipid
    ON #Subconto (ipid)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100
         );
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Subconto',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

    DECLARE @UnorderedItemID BIGINT = dbo.ItemNewGetBySysName('Item', 'UnorderedItem');
    DROP TABLE IF EXISTS #Main;
    CREATE TABLE #Main
    (
        Mandat VARCHAR(50) NOT NULL,
		DocCurrency BIGINT NOT NULL,
        FactAmount NUMERIC(15, 2) NULL,
        Cost NUMERIC(15, 2) NULL,
        ID BIGINT NOT NULL,
        PERIOD datetime NULL,
        DocDate DATETIME NULL,
        DocType BIGINT NULL,
        Posted TINYINT NOT NULL,
        State VARCHAR(150) NOT NULL,
        ItemGroupCode VARCHAR(100) NULL
    );
    INSERT #Main
    (
        Mandat,
		DocCurrency,
        FactAmount,
        Cost,
        ID,
        Period,
        DocDate,
        DocType,
        Posted,
        State,
        ItemGroupCode
    )
    SELECT T.Mandat,
	T.DocCurrency AS DocCurrency,
           (CASE
                WHEN T.DocTypeID = @MarketPlaceRealizatsiyaTSifrovyhTovarov THEN
                    ipdata.Cost
                WHEN T.DocTypeID = @PrihodIzProizvodstva THEN
                    ipdata.FactQty * ipdata.Price
                WHEN T.DocTypeID IN ( @AktVypolnennyhRabotPoReklameReklamnyKabinetPostavschika
                                  --    @NakladnayaRealizatsiiVGO3BC
                                    ) THEN
                    ipdata.Price
                WHEN T.DocTypeID = @AktVypolnennyhRabotSelleraIskhodyashchij THEN
                    ipdata.Price * ipdata.DocQty
                WHEN T.DocTypeID = @AktPriyemaTovarov THEN
                    ipdata.Price * (ipdata.FactQty - ipdata.DocQty)
                WHEN T.DocTypeID IN ( @AktOBrake, @AktOBrakeVes ) THEN
                    ipdata.FactQty * ipdata.Price
                WHEN T.DocTypeID IN ( @NakladnayaRealizatsiiVGO, @NakladnayaRealizatsiiVGOStorno ) THEN
                    ipdata.Price / (100 + ipdata.NDS) * 100 * ipdata.FactQty
                WHEN T.DocTypeID IN ( @RealizatsiyaOtgruzhennyhTovarovFizlitsamVGO,
                                      @KlientskiyVozvratRealizatsiiFizLitsVGO,
                                      @RealizatsiyaOtgruzhennyhTovarovFizlitsamStornoVGO,
									  @VozvratRealizatsiiOtgruzhennyhTovarovFizLitsamVGO
									  
                                    ) THEN
           (T.OperAmountCurr / T.OperAmount) * (ipdata.Price * ipdata.FactQty)
                WHEN T.DocTypeID = @DohodyBuduschihPeriodov THEN
                    SIGN(T.OperAmountCurr) * ipdata.DocQty * ipdata.Price
                WHEN T.DocTypeID = @AktNedostachiImporta THEN
                    ipdata.DocQty * ipdata.Price
                WHEN T.DocTypeID IN ( @NakladnayaZakupki, @NakladnayaNaKomissiyu, @NakladnayaNaRealizatsiyu,
                                      @NakladnayaNaHraneniye
                                    ) THEN
                    CASE
                        WHEN C.ItemGroupCode = 'TK5150M0000000036859' THEN --неопознанные излишки
                            C.Qty * ipdata.Price
                        WHEN T.IsNewInbound = 1
                             AND T.ItemID <> @UnorderedItemID
                             AND ipdata.FactQty > ipdata.DocQty THEN
                            ipdata.Price * (ipdata.FactQty - ipdata.ClaimQty)
                        WHEN ipdata.DocQty < ipdata.FactQty THEN
                            ipdata.Price * (ipdata.DocQty - ipdata.ClaimQty)
                        ELSE
                            ipdata.Price * (ipdata.FactQty - ipdata.ClaimQty)
                    END
                ELSE
                    ISNULL(ipdata.Price, 0)
                    * (T.Coefficient * ISNULL(C.Qty, ISNULL(ipdata.FactQty, 0) - ISNULL(ipdata.ClaimQty, 0)))
            END
           ) / (1 + CASE
                        WHEN T.DocTypeID IN ( @AktNedostachiImporta, @NakladnayaRealizatsiiVGO3BC ) THEN
                            ipdata.NDS / 100
                        ELSE
                            0
                    END
               ) AS FactAmount,
           CASE
               WHEN T.DocTypeID IN ( @AktONedostachi, @AktOBrake ) THEN
                   ipdata.Price * ipdata.DocQty
               WHEN T.DocTypeID = @AktOSpisaniiTovarov THEN
                   ISNULL(ipdata.Price, 0)
                   * (T.Coefficient * ISNULL(C.Qty, ISNULL(ipdata.FactQty, 0)) - ISNULL(ipdata.ClaimQty, 0))
               WHEN T.DocTypeID In (@VykupTovaraUSellera, @VykupTovaraUSelleraNeotFacturovano) THEN
                   ipdata.Cost
               ELSE
                   ISNULL(C.Cost, 0) * T.Coefficient
           END AS Cost,
          T.OriginalDocID AS ID,
           T.AccountingDate AS Period,
           T.DocDate AS DocDate,
          T.DocTypeID AS DocType,
           T.Posted,
           T.State,
           ISNULL(   Subconto.ItemCode,
                     CASE
                         WHEN C.IsmarketPlaceBBC = 1
                              AND C.ItemGroupCode = '00000011' THEN
                             '00000010'
                         WHEN C.IsmarketPlaceBBC = 1
                              AND C.ItemGroupCode = '00000010' THEN
                             '00000011'
                         ELSE
                             C.ItemGroupCode
                     END
                 ) AS ItemGroupCode
    FROM #Iposition AS T
        LEFT JOIN #NoReturnDelivery AS NRD WITH (INDEX(ipid)FORCESEEK)
            ON NRD.ipid = T.ipid
               AND NRD.pnum = T.pNum
        INNER JOIN dbo.ItemPosition_new AS ipdata WITH (INDEX([PK_ItemPosition_ID_pNum])FORCESEEK)
            ON ipdata.ID = T.ipid
               AND ipdata.pNum = T.pNum
        LEFT JOIN #Controlling AS C WITH (INDEX(ipid)FORCESEEK)
            ON C.Ipid = T.ipid
        LEFT JOIN #Subconto AS Subconto WITH (INDEX(ipid)FORCESEEK)
            ON Subconto.ipid = T.ipid
    WHERE NRD.ipid IS NULL
          AND T.DocTypeID <> @KomissionnoyeVoznagrazhdeniye
          AND NOT (C.ItemGroupCode='00000010' AND ipdata.FactQty > ipdata.DocQty AND T.DocTypeID = @NakladnayaNaKomissiyu)
    OPTION (MAXDOP 8);

    --@Претензия
    DECLARE @PersonLegalOCourierNewID BIGINT = dbo.ObjectGetBySysName('PersonLegal', 'PersonLegalOCourierNew'); -- "О-Курьер, ООО"   
    IF @TurnMetrics > 0
    BEGIN
        SELECT '#Main',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;

;

    DROP TABLE IF EXISTS #DocumentDataPreliminary;
    CREATE TABLE #DocumentDataPreliminary
    (
        Mandat VARCHAR(50) NOT NULL,
		DocCurrency BIGINT NOT NULL,
        FactAmount NUMERIC(15, 2) NULL,
        Cost NUMERIC(15, 2) NULL,
        ID BIGINT NOT NULL,
        PERIOD datetime NULL,
        DocDate DATETIME NULL,
        DocType BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        State VARCHAR(150) NULL,
        ItemGroupCode VARCHAR(100) NULL
    );
    INSERT #DocumentDataPreliminary
    (
        Mandat,
		DocCurrency,
        FactAmount,
        Cost,
        ID,
        Period,
        DocDate,
        DocType,
        Posted,
        State,
        ItemGroupCode
    )
    SELECT KomVoznagrazhdeniye.Mandat,
	KomVoznagrazhdeniye.DocCurrency,
           CASE
               WHEN SUM(KomVoznagrazhdeniye.RealizationCost) - SUM(KomVoznagrazhdeniye.Amount_realiz) > 0 THEN
                   SUM(KomVoznagrazhdeniye.Commission)
                   - (SUM(KomVoznagrazhdeniye.RealizationCost) - SUM(KomVoznagrazhdeniye.Amount_realiz))
               ELSE
                   SUM(KomVoznagrazhdeniye.Commission)
           END AS FactAmount,
           SUM(KomVoznagrazhdeniye.Amount_realiz) AS Cost,
           KomVoznagrazhdeniye.OriginalDocID AS ID,
           KomVoznagrazhdeniye.AccountingDate AS Period,
           KomVoznagrazhdeniye.DocDate AS DocDate,
           KomVoznagrazhdeniye.DocTypeID AS DocType,
           KomVoznagrazhdeniye.Posted AS Posted,
           KomVoznagrazhdeniye.State AS State,
           NULL AS ItemGroupCode
    FROM
    (
        SELECT T.Mandat,
		T.DocCurrency AS DocCurrency,
               ISNULL(Realization.Commission, 0) - ISNULL(Realization.ReturnCommission, 0) AS Commission,
               Realization.AmountOut AS Amount_realiz,
               0 AS RealizationCost,
               T.OriginalDocID,
               T.AccountingDate,
               T.DocDate,
               T.DocTypeID,
               T.Posted,
               T.State
        FROM #Iposition AS T
            JOIN dbo.ItemPositionRealization AS Realization WITH (INDEX(ItemPositionRealization_ID_XPK)FORCESEEK)
                ON Realization.ID = T.ipid
        WHERE T.DocTypeID = @KomissionnoyeVoznagrazhdeniye
        UNION ALL
        SELECT d.Mandat,
		d.DocCurrency,
               0,
               0,
               oie.Cost * CASE
                              WHEN oie.DirectoryID = @DirectoryOperationSaleReturn THEN
                                  -1
                              WHEN oie.DirectoryID = @DirectoryOperationSale THEN
                                  1
                              ELSE
                                  0
                          END,
               d.ID,
               d.AccountingDate,
               d.Date,
               d.DocTypeID,
               d.posted,
               d.state
        FROM #ComissionMarketPlace AS d
            JOIN dbo.ObjectItemExemplar AS oie
                ON oie.ID = d.ObjectItemID
        WHERE d.IsMarketPlaceDir = 0
    ) AS KomVoznagrazhdeniye
    GROUP BY KomVoznagrazhdeniye.OriginalDocID,
             KomVoznagrazhdeniye.AccountingDate,
             KomVoznagrazhdeniye.DocDate,
             KomVoznagrazhdeniye.DocTypeID,
             KomVoznagrazhdeniye.Posted,
             KomVoznagrazhdeniye.State,
             KomVoznagrazhdeniye.Mandat,
			 KomVoznagrazhdeniye.DocCurrency
    UNION ALL
    SELECT d.Mandat,
	d.DocCurrency,
           (oie.ComissionCalc - ((oie.Price - oie.PriceSale) - (oie.Commission - oie.ComissionCalc)))
           * CASE
                 WHEN oie.DirectoryID = @DirectoryOperationSaleReturn THEN
                     -1
                 WHEN oie.DirectoryID = @DirectoryOperationSale THEN
                     1
                 ELSE
                     0
             END,
           oie.PriceSale * CASE
                               WHEN oie.DirectoryID = @DirectoryOperationSaleReturn THEN
                                   -1
                               WHEN oie.DirectoryID = @DirectoryOperationSale THEN
                                   1
                               ELSE
                                   0
                           END,
           d.ID,
           d.AccountingDate,
           d.Date,
           d.DocTypeID,
           d.posted,
           d.state,
           NULL
    FROM #ComissionMarketPlace AS d
        JOIN dbo.ObjectItemExemplar AS oie
            ON oie.ID = d.ObjectItemID
    WHERE d.IsMarketPlaceDir = 1
    UNION ALL
    SELECT CO.Mandat,
	CO.DocCurrency,
           CASE
               WHEN En.EntryTypeId = @SpisaniyeSoSchetaSellera THEN
                   En.Amount
               WHEN En.EntryTypeId = @NachisleniyeKompensatsiiNaSchetsellera THEN
                   -En.Amount
               ELSE
                   0
           END,
           CASE
               WHEN En.EntryTypeId = @NachisleniyeNaSchetSellera THEN
                   En.Amount
               ELSE
                   0
           END,
           CO.OriginalDocID,
           CO.AccountingDate,
           CO.Date,
           CO.OriginalDocTypeID,
           CO.Posted,
           CO.State,
           NULL
    FROM #ProxyBilling AS CO
        JOIN dbo.Entry_new AS En
            ON En.ID = CO.EntryID
               AND En.Period = CO.Period
        JOIN #PartnersData AS PD WITH (INDEX(DOCID)FORCESEEK)
            ON PD.DocID = CO.OriginalDocID
               AND PD.AccountID = CO.AccountID
    UNION ALL
	
    SELECT d.Mandat AS Mandat,
	d.DocCurrency AS DocCurrency,
           CASE
               WHEN d.DocTypeID = @FakticheskayaOplataSellerovStorno THEN
                   -1
               ELSE
                   1
           END * ISNULL(d.AmountCurr, 0) 
		   * CASE WHEN d.DocTypeID = @PeredachaPPnaOtvetHraneniyeVGO 
		  THEN 100/(100 + d.NDS) ELSE 1 End 
		   + CASE
                                               WHEN d.DocTypeID = @GTD THEN
                                                   ISNULL(d.Amount, 0)
                                               ELSE
                                                   0
                                           END AS FactAmount,
           0 AS Cost,
           d.OriginalDocID AS ID,
           d.AccountingDate AS Period,
           d.Date AS DocDate,
           d.DocTypeID AS DocType,
           d.Posted AS Posted,
           d.State AS State,
           CASE
               WHEN d.DocTypeID = @PriemNaOtvetHraneniyeVGO THEN
                   '00000011'
				WHEN d.DocTypeID = @PaletnayaPriemka THEN 
				'00000010'

               ELSE
                   NULL
           END AS ItemGroupCode
    FROM #Docs AS d
    WHERE d.DocTypeID IN ( @AktVypolnennyhRabotPartnera, @AktPriyemkiPeredachi, @AktPriyemkiPeredachiPredvaritelno,
                           @NachisleniyePartnerskogoVoznagrazhdeniya, @GTD, @AktPoRetroBonusam,
                           @AktPoRetroBonusamPredvaritelno, @MarketPlaceKorrektirovkaSummKomissionnyhTovarov,
                           @SmenaTVRAgenta, @NachisleniyaNaPS, @VozvratPlatezheyCHerezBank,
                           @VozvratPlatezheyCHerezPochtu, @ZachetTrebovaniy, @SHtrafnayaSanktsiya,
                           @FakticheskayaOplataSellerov, @SpravkaKProchimSpisaniyamDenegEkvayring,
                           @FakticheskayaOplataSellerovStorno, @KomissionnoyeVoznagrazhdeniyeTrevel,
                           @FakticheskayaOplataPostavschikov, @ReyestrOplatPostavschiku, @SHtrafnayaSanktsiyaTovarnaya,
                           @RaspredelenieNeidentifitsirovannogoPlatejaNaZakaz, @PriemNaOtvetHraneniyeVGO,
                           @PerevystavleniyeUslugSMZ, @MarketPlaceVoznagrazhdenieSelleraZaObyemProdazhAccruals,
                           @MarketPlaceVoznagrazhdenieSelleraZaObyemProdazh, @PaletnayaPriemka, @PeredachaPPnaOtvetHraneniyeVGO
                         )
    UNION ALL
    SELECT d.Mandat AS Mandat,
	d.DocCurrency,
           ISNULL(Link.AmountCurr, 0) + ISNULL(docdata.AmountNDS, 0) AS factAmount,
           0 AS Cost,
           d.OriginalDocID AS ID,
           d.AccountingDate AS Period,
           d.Date AS DocDate,
           d.DocTypeID AS DocType,
           d.Posted AS Posted,
           d.State AS State,
           --  Case When d.DocTypeID = @PriemNaOtvetHraneniyeVGO Then '00000011' Else NULL End As ItemGroupCode 
           NULL AS ItemGroupCode
    FROM #Docs AS d
        JOIN dbo.DocumentAmountLink AS Link
            ON d.ID = Link.LinkDocumentId
        JOIN dbo.Document AS docdata
            ON d.ID = docdata.ID
    WHERE d.DocTypeID IN ( @AktVypolnennyhRabotPoInvoysu )
    UNION ALL
    SELECT d.Mandat,
	d.DocCurrency,
           VAT.VATAmount,
           0,
           d.ID,
           d.AccountingDate,
           d.Date,
           d.DocTypeID,
           d.Posted,
           d.State,
           NULL
    FROM #Docs AS d
        JOIN dbo.DocumentVATAmountPart AS VAT
            ON d.ID = VAT.DocumentId
               AND d.DocTypeID = @GTD
    UNION ALL
    SELECT CO.Mandat,
	CO.DocCurrency,
           CO.FactAmount,
           CO.Cost,
           CO.ID,
           CO.AccountingDate,
           CO.Date,
           CO.DocTypeID,
           CO.Posted,
           CO.State,
           NULL
    FROM #ClearingOperations AS CO
    WHERE CO.DocTypeID NOT IN ( @OtrazhenityVyruchkiSellera, @Pretenziya )
    UNION ALL
    SELECT d.Mandat,
	d.DocCurrency,
           ipi.CurrPrice * ip.DocQty AS FactAmount,
           0,
           d.OriginalDocID,
           d.AccountingDate,
           d.Date,
           d.DocTypeID,
           1,
           d.State,
           '00000010'
    FROM #Docs AS d
        JOIN dbo.ItemPosition_new AS ip
            ON ip.ObjectID = d.ID
               AND ip.pNum = d.pNum
        JOIN dbo.ItemPositionInvoice AS ipi
            ON ipi.ID = ip.ID
    WHERE d.DocTypeID IN ( @Invoys )
    UNION ALL
    SELECT d.Mandat,
	d.DocCurrency,
           CASE
               WHEN d.DocTypeID = @Invoys THEN
                   Doclink.AmountCurr
               ELSE
                   Doclink.Amount
           END,
           0,
           d.OriginalDocID,
           d.AccountingDate,
           d.Date,
           d.DocTypeID,
           1,
           d.State,
           NULL
    FROM #Docs AS d
        JOIN dbo.DocumentAmountLink AS Doclink
            ON Doclink.DocumentId = d.ID
    WHERE d.DocTypeID IN ( @PerdachaNaOtvetHraneniyeVGO )
    UNION ALL
    SELECT Certificates.Mandat,
	@RUR,
           SUM(Certificates.NominalValue),
           CASE
               WHEN ISNULL(SUM(Certificates.PayAmount), 0) = 0 THEN
                   0
               ELSE
                   SUM(Certificates.NominalValue) - SUM(Certificates.PayAmount)
           END,
           Certificates.ID,
           Certificates.AccountingDate,
           Certificates.Date,
           Certificates.DocTypeID,
           Certificates.Posted,
           Certificates.State,
           NULL
    FROM
    (
        SELECT d.Mandat,
               d.NominalValue AS NominalValue,
               0 AS PayAmount,
               d.ID,
               d.DocTypeID,
               d.AccountingDate,
               d.Date,
               d.Posted,
               d.State
        FROM #CertificateNominalValue AS d
        UNION ALL
        SELECT d.Mandat,
               0,
               ISNULL(DSTA.PayAmount, 0),
               d.ID,
               d.DocTypeID,
               d.AccountingDate,
               d.Date,
               d.Posted,
               d.State
        FROM #Docs AS d
            LEFT JOIN dbo.DocumentCertificateTransferAct AS DSTA
                ON DSTA.ID = d.ID
        WHERE d.DocTypeID IN ( @AktPeredachiSertifikatov )
    ) AS Certificates
    GROUP BY Certificates.Mandat,
             Certificates.ID,
             Certificates.AccountingDate,
             Certificates.Date,
             Certificates.DocTypeID,
             Certificates.Posted,
             Certificates.State
    UNION ALL
    SELECT d.Mandat,
	@RUR,
           SUM(   d.NominalValue - (CASE
                                        WHEN ISNULL(CD.Discount, 0) = 0 THEN
                                            0
                                        WHEN CD.Discount > d.NominalValue THEN
                                            0
                                        ELSE
                                            d.NominalValue - ISNULL(CD.Discount, 0)
                                    END
                                   )
              ),
           0,
           d.ID,
           d.AccountingDate,
           d.date,
           d.DocTypeID,
           d.Posted,
           d.State,
           NULL
    FROM #CertificateRealization AS d
        LEFT JOIN #CertificateDiscount AS CD
            ON CD.ContractID = d.ContractID
    GROUP BY d.Mandat,
             d.AccountingDate,
             d.date,
             d.DocTypeID,
             d.Posted,
             d.State,
             d.ID
    UNION ALL
    SELECT d.Mandat,
	@RUR,
           SUM(S.NominalValue),
           0,
           d.ID,
           d.AccountingDate,
           d.Date,
           d.DocTypeID,
           d.Posted,
           d.State,
           NULL
    FROM #Docs AS d
        JOIN dbo.CertificateByDocument AS C
            ON C.DocumentID = d.ID
        JOIN dbo.CertificateForPurchase AS S
            ON C.CertificateID = S.ID
    WHERE d.DocTypeID = @AktPeredachiSertifikatovPlastik
    GROUP BY d.ID,
             d.AccountingDate,
             d.Date,
             d.DocTypeID,
             d.Posted,
             d.Mandat,
             d.State
    UNION ALL
    SELECT d.Mandat,
	d.DocCurrency,
           SUM(ip.FactWeight * ip.PricePerKG) AS FactAmount,
           SUM(ip.Weight * ip.PricePerKG) AS Cost,
           d.ID,
           d.AccountingDate,
           d.Date,
           d.OriginalDocTypeID,
           d.Posted,
           d.State,
           NULL
    FROM #Docs AS d
        JOIN dbo.ItemPositionBulkItem AS ip
            ON ip.DocumentId = d.ID
    WHERE d.DocTypeID IN ( @AktOBrakeVes, @AktONedostacheVes )
    GROUP BY d.ID,
             d.AccountingDate,
             d.Date,
             d.OriginalDocTypeID,
             d.Posted,
             d.Mandat,
             d.State,
			 d.DocCurrency
    UNION ALL
    SELECT OperationLinkExemlar.Mandat,
	OperationLinkExemlar.DocCurrency,
           CASE
               WHEN OperationLinkExemlar.DocTypeID = @AktSpisaniyaTovarovUtilizirovannyhVDostavke
                    AND acc.ItemGroupCode = '00000011' THEN
                   ie.Price
               WHEN OperationLinkExemlar.DocTypeID = @AktSpisaniyaTovarovUtilizirovannyhVDostavke
                    AND acc.ItemGroupCode <> '00000011' THEN
                   ROUND(ie.Price * 100.00 / (100.00 + ISNULL(ie.NDS, 0.00)), 2)
               ELSE
                   OperationLinkExemlar.Price
           END AS FactAmount,
           CASE
               WHEN OperationLinkExemlar.DocTypeID = @AktSpisaniyaTovarovUtilizirovannyhVDostavke THEN
                   0
               WHEN acc.ItemGroupCode = '00000011' THEN
                   ie.Price
               ELSE
                   ROUND(ie.Price * 100.00 / (100.00 + ISNULL(ie.NDS, 0.00)), 2)
           END AS Cost,
           OperationLinkExemlar.docid,
           OperationLinkExemlar.AccountingDate,
           OperationLinkExemlar.Date,
           OperationLinkExemlar.DocTypeID,
           OperationLinkExemlar.Posted,
           OperationLinkExemlar.state,
           acc.ItemGroupCode
    FROM #OperationLinkExemlar AS OperationLinkExemlar
        JOIN dbo.ItemExemplar AS ie
            ON ie.ID = OperationLinkExemlar.ExemplarID
        LEFT JOIN dbo.AccountGroupView AS acc
            ON acc.AccountGroupDirID = ie.AccountGroupDirID
    UNION ALL
    SELECT DISTINCT
           d.Mandat,
		   d.DocCurrency,
           d.AmountCurr,
           0,
           d.OriginalDocID,
           d.AccountingDate,
           d.Date,
           d.DocTypeID,
           d.Posted,
           d.State,
           '00000002'
    FROM #Docs AS d
        JOIN dbo.Document AS ClaimOCourierToSelfTake
            ON ClaimOCourierToSelfTake.ID = d.ID
               AND ClaimOCourierToSelfTake.SenderPersonID = @PersonLegalOCourierNewID
    WHERE d.DocTypeID = @Pretenziya
    UNION ALL
    SELECT d.Mandat,
	d.DocCurrency,
           pr.Fee AS FactAmount,
           0 AS Cost,
           d.ID,
           d.AccountingDate,
           d.Date,
           d.DocTypeID,
           d.Posted,
           d.State,
           NULL
    FROM #Docs AS d
        JOIN dbo.PaychargePATransactionRegistryDocument AS pr
            ON pr.ID = d.ID
   UNION ALL
    select  'MSK' as Mandat,
 d.CurrencyID AS DocCurrency,
 h.DocumentSum AS FactAmount,
 0 as Cost,
 h.SrcID as  ID,
d.AccountingDate as PERIOD,
 h.Date as DocDate,
 @HumanAdvanceVATReport as DocType,
 CASE
               WHEN ISNULL(ObjState.Name, 'Формируется') = 'Формируется' THEN
                   0
               ELSE
                   ISNULL(DocState.Active, 0)
           END AS Posted,
           ISNULL(ObjState.Name, 'Формируется') AS State, 

'' as ItemGroupCode 
from #HumanAdvanceVATReport as h
 JOIN dbo.Document AS d
       ON d.ID = h.SrcID
INNER JOIN dbo.Object AS o
            ON (h.SrcID = o.ID)
		LEFT JOIN dbo.State AS DocState
            ON DocState.ID = o.StateID
        LEFT JOIN dbo.Object AS ObjState
            ON ObjState.ID = o.StateID        
    OPTION (MAXDOP 8);
    CREATE STATISTICS agg_Stat ON #Main (ID, ItemGroupCode, Mandat);
    CREATE STATISTICS ID_Stat
    ON #DocumentDataPreliminary
    (
        ID,
        ItemGroupCode,
        Mandat
    );
    DROP TABLE #Iposition;
    DROP TABLE #Controlling;

    IF @TurnMetrics > 0
    BEGIN
        SELECT '#DocumentDataPreliminary',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #DocumentData;
    CREATE TABLE #DocumentData
    (
        Mandat VARCHAR(15) NOT NULL,
		DocCurrency BIGINT NOT NULL,
        FactAmount NUMERIC(15, 2) NULL,
        Cost NUMERIC(15, 2) NULL,
        ID BIGINT NOT NULL,
        PERIOD DATETIME NULL,
        DocDate DATETIME NULL,
        DocType BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        State VARCHAR(150) NULL,
        ItemGroupCode VARCHAR(100) NULL
    );

    INSERT #DocumentData
    (
        Mandat,
		DocCurrency,
        FactAmount,
        Cost,
        ID,
        PERIOD,
        DocDate,
        DocType,
        Posted,
        State,
        ItemGroupCode
    )
    SELECT d.Mandat AS Mandat,
	MAX(d.DocCurrency) AS DocCurrency,
           SUM(d.FactAmount) AS FactAmount,
           SUM(d.Cost) Cost,
           d.ID AS ID,
           MAX(d.PERIOD) AS PERIOD,
           MAX(d.DocDate) AS DocDate,
           MAX(d.DocType) AS DocType,
           MAX(d.Posted) AS Posted,
           MAX(d.State) AS State,
           d.ItemGroupCode AS ItemGroupCode
    FROM #Main AS d
    GROUP BY d.ID,
             d.ItemGroupCode,
             d.Mandat
    OPTION (MAXDOP 8);
    DROP TABLE #Main;

    INSERT #DocumentData
    (
        Mandat,
		DocCurrency,
        FactAmount,
        Cost,
        ID,
        PERIOD,
        DocDate,
        DocType,
        Posted,
        State,
        ItemGroupCode
    )
    SELECT d.Mandat AS Mandat,
	MAX(d.DocCurrency) AS DocCurrency,
           SUM(d.FactAmount) AS FactAmount,
           SUM(d.Cost) Cost,
           d.ID AS ID,
           MAX(d.PERIOD) AS PERIOD,
           MAX(d.DocDate) AS DocDate,
           MAX(d.DocType) AS DocType,
           MAX(d.Posted) AS Posted,
           MAX(d.State) AS State,
           d.ItemGroupCode AS ItemGroupCode
    FROM #DocumentDataPreliminary AS d
    GROUP BY d.ID,
             d.ItemGroupCode,
             d.Mandat
    OPTION (MAXDOP 8);
    DROP TABLE #DocumentDataPreliminary;
    CREATE STATISTICS ID_Stat ON #DocumentData (ID);
    CREATE CLUSTERED INDEX ID
    ON #DocumentData (ID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100
         );

    IF @TurnMetrics > 0
    BEGIN
        SELECT 'DocumentData',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
        SET @StartOperation = GETDATE();
    END;
    DROP TABLE IF EXISTS #Result;
    CREATE TABLE #Result
    (
        Mandat VARCHAR(15) NOT NULL,
		DocCurrency VARCHAR (3) NOT NULL,
        FactAmount NUMERIC(15, 2) NOT NULL,
        Cost NUMERIC(15, 2) NOT NULL,
        ID BIGINT NOT NULL,
        PERIOD DATETIME NOT NULL,
        DocDate DATETIME NULL,
        DocType BIGINT NOT NULL,
        Posted TINYINT NOT NULL,
        State VARCHAR(150) NOT NULL,
        ItemGroupCode VARCHAR(100) NOT NULL,
        Contract BIGINT NULL,
        PayProp BIGINT NULL,
        OwnerID BIGINT NULL,
        INN VARCHAR(100) NULL,
        KPP VARCHAR(20) NULL,
        Country VARCHAR(5) NULL,
        OwnerINN VARCHAR(100) NULL,
        OwnerKPP VARCHAR(20) NULL,
        Name VARCHAR(150) NULL
    );
    INSERT #Result
    (
        Mandat,
		DocCurrency,
        FactAmount,
        Cost,
        ID,
        PERIOD,
        DocDate,
        DocType,
        Posted,
        State,
        ItemGroupCode,
        Contract,
        PayProp,
        OwnerID,
        INN,
        KPP,
        Country,
        OwnerINN,
        OwnerKPP,
        Name
    )
    SELECT DD.Mandat AS Mandat,
	ISNULL(ContractCurrency.RCCNumb, Currency.RCCNumb)  AS DocCurrency,
           ISNULL(DD.FactAmount, 0) AS FactAmount,
           ISNULL(DD.Cost, 0) AS Cost,
           DD.ID AS ID,
           ISNULL(DD.PERIOD, '19000101') AS Period,
           DD.DocDate AS DocDate,
           DD.DocType AS DocType,
           DD.Posted AS Posted,
           DD.State AS State,
           CASE
               WHEN DD.DocType IN ( @AktPriyemaTovarov, @AktONedostachi, @AktONedostacheVes, @AktOBrake, @AktOBrakeVes ) THEN
                   CASE
                       WHEN PD.ContractType IN ( @ContractPurchase, @ContractPurchasePostPay ) THEN
                           '00000010'
                       WHEN PD.ContractType = @ContractCommission THEN
                           '00000011'
                       WHEN PD.ContractType = @ContractStorage THEN
                           '00000012'
                       ELSE
                           ''
                   END
               WHEN DD.DocType IN ( @VykupTovaraUSellera, @AktNedostachiImporta ) THEN
                   '00000010'
               ELSE
                   ISNULL(DD.ItemGroupCode, '')
           END AS ItemGroupCode,
           PD.Contract AS Contract,
           PD.PayProp AS PayProp,
           PD.OwnerID AS OwnerID,
           PD.INN AS INN,
           PD.KPP AS KPP,
           CASE
               WHEN Dir.ID IS NULL THEN
                   '643'
               ELSE
                   CONCAT(REPLICATE('0', 3 - DATALENGTH(Dir.Code)), Dir.Code)
           END AS Country,
           PD.OwnerINN AS OwnerINN,
           PD.OwnerKPP AS OwnerKPP,
           PD.Name AS Name
    FROM #DocumentData AS DD
        LEFT JOIN #PartnersData AS PD
            ON PD.DocID = DD.ID
        LEFT JOIN dbo.Directory AS Dir
            ON Dir.ID = PD.Country
		 JOIN dbo.Currency AS Currency
		 ON Currency.ID = DD.DocCurrency
		 LEFT JOIN dbo.Currency AS ContractCurrency
		 ON ContractCurrency.ID = PD.ContractCurrency
		 AND PD.ISVGO = 1
		 AND DD.DocType <> @NakladnayaRealizatsiiVGO3BC
    UNION ALL
    SELECT DD.Mandat AS Mandat,
	MAX(Currency.RCCNumb),
           SUM(   CASE
                      WHEN DD.IsDebit = 1 THEN
                          DD.Amount
                      ELSE
                          0
                  END
              ) AS FactAmount,
           0 AS Cost,
           DD.docid AS ID,
           ISNULL(DD.AccountingDate, '19000101') AS Period,
           DD.Date AS DocDate,
           DD.doctypeid AS DocType,
           DD.Posted AS Posted,
           DD.STATE AS State,
           '' AS ItemGroupCode,
           PD.Contract AS Contract,
           PD.PayProp AS PayProp,
           PD.OwnerID AS OwnerID,
           PD.INN AS INN,
           PD.KPP AS KPP,
           MAX(   CASE
                      WHEN Dir.ID IS NULL THEN
                          '643'
                      ELSE
                          CONCAT(REPLICATE('0', 3 - DATALENGTH(Dir.Code)), Dir.Code)
                  END
              ) AS Country,
           PD.OwnerINN AS OwnerINN,
           PD.OwnerKPP AS OwnerKPP,
           PD.Name AS Name
    FROM #ContractsInOperations AS DD
        LEFT JOIN #PartnersData AS PD
            ON PD.DocID = DD.opid
        LEFT JOIN dbo.Directory AS Dir
            ON Dir.ID = PD.Country
			JOIN dbo.Currency AS Currency
		 ON Currency.ID = DD.DocCurrency
    GROUP BY DD.Mandat,
             DD.docid,
             DD.AccountingDate,
             DD.Date,
             DD.doctypeid,
             DD.Posted,
             DD.STATE,
             PD.Contract,
             PD.PayProp,
             PD.OwnerID,
             PD.INN,
             PD.KPP,
             PD.OwnerINN,
             PD.OwnerKPP,
             PD.Name
    OPTION (MAXDOP 8);
    CREATE STATISTICS ID_Stat ON #Result (ID);
    CREATE CLUSTERED INDEX ID
    ON #Result (ID)
    WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = ON, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF,
          ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100
         );

    --Set Statistics XML OFF;

    IF @Portion > 0
    BEGIN
        DECLARE @MaxID BIGINT;
        SELECT TOP (1)
               @MaxID = DD.ID
        FROM #Result AS DD
        ORDER BY DD.ID DESC;
        DECLARE @Counter BIGINT = 0;
        DECLARE @LastID BIGINT = 0;

        DECLARE @t VARCHAR(MAX);

        DROP TABLE IF EXISTS #XMLData;
        CREATE TABLE #XMLData
        (
            ItemXML VARCHAR(MAX) NOT NULL
        );

        WHILE 1 = 1
        BEGIN

            SELECT TOP (10000) WITH TIES
                   @LastID = R.ID
            FROM #Result AS R
            WHERE R.ID > @Counter
            ORDER BY R.ID;

            SET @t =
            (
                SELECT R.Mandat AS Mandat,			
                       R.FactAmount AS FactAmount,
                       R.Cost AS Cost,
                       CONVERT(VARCHAR(20), R.ID) AS ID,
                       R.PERIOD AS Period,
                       R.DocDate AS DocDate,
                       R.DocType AS DocType,
                       R.Posted AS Posted,
                       R.State AS State,
                       R.ItemGroupCode AS ItemGroupCode,
                       ISNULL(CONVERT(VARCHAR(20), R.Contract), '') AS Contract,
                       ISNULL(CONVERT(VARCHAR(20), R.PayProp), '') AS PayProp,
                       ISNULL(CONVERT(VARCHAR(20), R.OwnerID), '') AS OwnerID,
                       ISNULL(R.INN, '') AS INN,
                       ISNULL(R.KPP, '') AS KPP,
                       R.Country AS Country,
                       ISNULL(R.OwnerINN, '') AS OwnerINN,
                       ISNULL(R.OwnerKPP, '') AS OwnerKPP,
                       @Updated AS _Updated,
                       ISNULL(R.Name, '') AS Name,
					   	R.DocCurrency AS DocCurrency
                FROM #Result AS R
                WHERE R.ID > @Counter
                      AND R.ID <= @LastID
                FOR XML RAW('Row')
            );

            IF @t IS NOT NULL
            BEGIN
                INSERT #XMLData
                (
                    ItemXML
                )
                SELECT @t;
            END;
            SET @Counter = @LastID;

            IF @Counter = @MaxID
               OR @LastID = 0
                BREAK;
        END;

        SELECT XMLData.ItemXML
        FROM #XMLData AS XMLData;
    END;
    ELSE
    BEGIN
      /* DELETE FROM garbage.dbo.akuznetsov WITH (TABLOCK)  
WHERE (period BETWEEN @BeginPeriod AND @EndPeriod)  
Or (IsNULL(Period,'19000101') =  '19000101' and DocDate  BETWEEN @BeginPeriod AND @EndPeriod)    
INSERT garbage.dbo.akuznetsov WITH (tablock)*/

        SELECT R.Mandat AS Mandat,
		R.DocCurrency AS DocCurrency,
               R.FactAmount AS FactAmount,
               R.Cost AS Cost,
               CONVERT(VARCHAR(20), R.ID) AS ID,
               R.PERIOD AS Period,
               R.DocDate AS DocDate,
               R.DocType AS DocType,
               R.Posted AS Posted,
               R.State AS State,
               R.ItemGroupCode AS ItemGroupCode,
               ISNULL(CONVERT(VARCHAR(20), R.Contract), '') AS Contract,
               ISNULL(CONVERT(VARCHAR(20), R.PayProp), '') AS PayProp,
               ISNULL(CONVERT(VARCHAR(20), R.OwnerID), '') AS OwnerID,
               ISNULL(R.INN, '') AS INN,
               ISNULL(R.KPP, '') AS KPP,
               R.Country AS Country,
               ISNULL(R.OwnerINN, '') AS OwnerINN,
               ISNULL(R.OwnerKPP, '') AS OwnerKPP,
               @Updated AS _Updated,
               ISNULL(R.Name, '') AS Name,
               0 AS CostRURRK
        FROM #Result AS R;
    END;

    IF @TurnMetrics > 0
    BEGIN
        SELECT 'Main',
               DATEDIFF(SECOND, @StartOperation, GETDATE());
    END;
