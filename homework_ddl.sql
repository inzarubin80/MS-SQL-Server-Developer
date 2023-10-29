USE [master]
GO

/****** Object:  Database [BookingServices]    Script Date: 01.10.2023 13:49:39 ******/
CREATE DATABASE [BookingServices]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'BookingServices', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQL2022\MSSQL\DATA\BookingServices.mdf' , SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'BookingServices_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQL2022\MSSQL\DATA\BookingServices_log.ldf' , SIZE = 8192KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT, LEDGER = OFF
GO

ALTER DATABASE [BookingServices] MODIFY FILEGROUP [PRIMARY] AUTOGROW_ALL_FILES
GO

IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [BookingServices].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO

ALTER DATABASE [BookingServices] SET ANSI_NULL_DEFAULT OFF 
GO

ALTER DATABASE [BookingServices] SET ANSI_NULLS OFF 
GO

ALTER DATABASE [BookingServices] SET ANSI_PADDING OFF 
GO

ALTER DATABASE [BookingServices] SET ANSI_WARNINGS OFF 
GO

ALTER DATABASE [BookingServices] SET ARITHABORT OFF 
GO

ALTER DATABASE [BookingServices] SET AUTO_CLOSE OFF 
GO

ALTER DATABASE [BookingServices] SET AUTO_SHRINK OFF 
GO

ALTER DATABASE [BookingServices] SET AUTO_UPDATE_STATISTICS ON 
GO

ALTER DATABASE [BookingServices] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO

ALTER DATABASE [BookingServices] SET CURSOR_DEFAULT  GLOBAL 
GO

ALTER DATABASE [BookingServices] SET CONCAT_NULL_YIELDS_NULL OFF 
GO

ALTER DATABASE [BookingServices] SET NUMERIC_ROUNDABORT OFF 
GO

ALTER DATABASE [BookingServices] SET QUOTED_IDENTIFIER OFF 
GO

ALTER DATABASE [BookingServices] SET RECURSIVE_TRIGGERS OFF 
GO

ALTER DATABASE [BookingServices] SET  DISABLE_BROKER 
GO

ALTER DATABASE [BookingServices] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO

ALTER DATABASE [BookingServices] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO

ALTER DATABASE [BookingServices] SET TRUSTWORTHY OFF 
GO

ALTER DATABASE [BookingServices] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO

ALTER DATABASE [BookingServices] SET PARAMETERIZATION SIMPLE 
GO

ALTER DATABASE [BookingServices] SET READ_COMMITTED_SNAPSHOT OFF 
GO

ALTER DATABASE [BookingServices] SET HONOR_BROKER_PRIORITY OFF 
GO

ALTER DATABASE [BookingServices] SET RECOVERY FULL 
GO

ALTER DATABASE [BookingServices] SET  MULTI_USER 
GO

ALTER DATABASE [BookingServices] SET PAGE_VERIFY CHECKSUM  
GO

ALTER DATABASE [BookingServices] SET DB_CHAINING OFF 
GO

ALTER DATABASE [BookingServices] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO

ALTER DATABASE [BookingServices] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO

ALTER DATABASE [BookingServices] SET DELAYED_DURABILITY = DISABLED 
GO

ALTER DATABASE [BookingServices] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO

ALTER DATABASE [BookingServices] SET QUERY_STORE = ON
GO



ALTER DATABASE [BookingServices] SET  READ_WRITE 
GO

USE [BookingServices]
GO

CREATE TABLE [dbo].[TypeBusiness](
	[TypeBusinessID] [bigint] IDENTITY(1,1) NOT NULL,
	[TypeBusinessName ] [nvarchar](100) NULL,
	[Description ] [nvarchar](100) NOT NULL,
	[NameServiceProducers] [nvarchar](100) NOT NULL,
	[UseMultipleSlotBooking] [bit] NOT NULL,
	[MarkDeletion] [bit] NULL,
	[UseSelectSlotService] [bit] NOT NULL,
 CONSTRAINT [PK_TypeBusiness] PRIMARY KEY CLUSTERED 
(
	[TypeBusinessID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE TypeBusiness
ADD CONSTRAINT UC_TypeBusiness_TypeBusinessName UNIQUE (TypeBusinessName)

INSERT INTO [dbo].[TypeBusiness]
           ([TypeBusinessName ]
           ,[Description ]
           ,[NameServiceProducers]
           ,[UseMultipleSlotBooking]
           ,[MarkDeletion]
           ,[UseSelectSlotService])
     VALUES
           ('Парикмахерская'
           ,'Здесь стригут людей'
           ,'Парикмахеры'
           ,0
           ,0
           ,0),
            ('Автомойка'
           ,'Здесь моют автомобили'
           ,'Боксы'
           ,0
           ,0
           ,0)

CREATE TABLE [dbo].[UsersRoles](
	[RoleID] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NULL,
	[description] [nvarchar](250) NULL,
 CONSTRAINT [PK_UsersRoles] PRIMARY KEY CLUSTERED 
(
	[RoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE UsersRoles
ADD CONSTRAINT UC_UsersRoles_Name UNIQUE (name)


INSERT INTO [dbo].[UsersRoles]
           ([name]
           ,[description])
     VALUES
           ('Admin'
           ,'Администратор приложения'),

           ('ServiceProvider'
           ,'Поставщик услуг'),

           ('ServiceСonsumer'
           ,'Потребитель услуг')
      
CREATE TABLE Users (
  UserID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
  UserName NVARCHAR(50),
  Password NVARCHAR(50),
  RoleID INT,
  Email NVARCHAR(256),
  Phone NVARCHAR(20),
  INDEX IX_RoleID (RoleID),
  FOREIGN KEY (RoleID) REFERENCES UsersRoles(RoleID)
);

INSERT INTO [dbo].[Users]
           ([UserName]
           ,Password
           ,RoleID
           ,Email
           ,Phone
           )
     VALUES
           ('Admin'
           ,''
           ,1
           ,'admin@bookingservice.com'
           ,'89169370850'),

      ('Service provider'
           ,''
           ,1
           ,'admin@company.com'
           ,'89169370851'),

    ('Service consumer'
           ,''
           ,1
           ,'ivan@company.com'
           ,'89169370852')

ALTER TABLE Users
ADD CONSTRAINT UC_Users_Email UNIQUE (Email)
