CREATE DATABASE FINANCE_MANAGER
USE FINANCE_MANAGER

CREATE TABLE dbo.Users (
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_Users PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    FirebaseUid NVARCHAR(128) NOT NULL,
    Email NVARCHAR(320) NULL,
    DisplayName NVARCHAR(150) NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_Users_FirebaseUid UNIQUE (FirebaseUid)
);

CREATE TABLE dbo.Households (
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_Households PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    Name NVARCHAR(150) NOT NULL,
    CreatedByUserId UNIQUEIDENTIFIER NOT NULL,
    ApprovalThreshold DECIMAL(18,2) NOT NULL DEFAULT 1000000,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Households_Creator
        FOREIGN KEY (CreatedByUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Households_Threshold
        CHECK (ApprovalThreshold >= 0)
);

CREATE TABLE dbo.HouseholdMembers (
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_HouseholdMembers PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    HouseholdId UNIQUEIDENTIFIER NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    [Role] TINYINT NOT NULL,   -- 0 Owner, 1 Admin, 2 Member
    [Status] TINYINT NOT NULL DEFAULT 1, -- 0 Invited, 1 Active, 2 Left
    CanViewIncomeDetails BIT NOT NULL DEFAULT 0,
    CanApproveExpenses BIT NOT NULL DEFAULT 0,
    JoinedAt DATETIME2 NULL,
    CONSTRAINT FK_HouseholdMembers_Household
        FOREIGN KEY (HouseholdId) REFERENCES dbo.Households(Id),
    CONSTRAINT FK_HouseholdMembers_User
        FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT UQ_HouseholdMembers_Household_User
        UNIQUE (HouseholdId, UserId),
    CONSTRAINT CK_HouseholdMembers_Role CHECK ([Role] IN (0,1,2)),
    CONSTRAINT CK_HouseholdMembers_Status CHECK ([Status] IN (0,1,2))
);

-- Một người chỉ được thuộc tối đa một gia đình đang hoạt động.
CREATE UNIQUE INDEX UX_HouseholdMembers_OneActiveHousehold
ON dbo.HouseholdMembers(UserId)
WHERE [Status] = 1;

CREATE TABLE dbo.Accounts (
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_Accounts PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    OwnerUserId UNIQUEIDENTIFIER NOT NULL,
    HouseholdId UNIQUEIDENTIFIER NULL,
    Name NVARCHAR(100) NOT NULL,
    [Type] TINYINT NOT NULL, -- 0 Cash, 1 BankDemo, 2 EWalletDemo
    OpeningBalance DECIMAL(18,2) NOT NULL DEFAULT 0,
    IsDemo BIT NOT NULL DEFAULT 1,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Accounts_Owner
        FOREIGN KEY (OwnerUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Accounts_Household
        FOREIGN KEY (HouseholdId) REFERENCES dbo.Households(Id)
);

CREATE TABLE dbo.Categories (
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_Categories PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    Name NVARCHAR(100) NOT NULL,
    [Type] TINYINT NOT NULL, -- 0 Expense, 1 Income
    IsSystem BIT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT CK_Categories_Type CHECK ([Type] IN (0,1))
);

CREATE TABLE dbo.Transactions (
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_Transactions PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    HouseholdId UNIQUEIDENTIFIER NULL,
    CreatedByUserId UNIQUEIDENTIFIER NOT NULL,
    AccountId UNIQUEIDENTIFIER NOT NULL,
    CategoryId UNIQUEIDENTIFIER NULL,
    [Type] TINYINT NOT NULL, -- 0 Expense, 1 Income, 2 Transfer
    Amount DECIMAL(18,2) NOT NULL,
    TransactionDate DATETIME2 NOT NULL,
    Note NVARCHAR(1000) NULL,
    Visibility TINYINT NOT NULL DEFAULT 0,
    -- 0 Private, 1 Household, 2 SelectedMembers
    [Status] TINYINT NOT NULL DEFAULT 0,
    -- 0 Draft, 1 PendingApproval, 2 Approved, 3 Rejected, 4 Cancelled
    RequiresApproval BIT NOT NULL DEFAULT 0,
    ApprovedByUserId UNIQUEIDENTIFIER NULL,
    ApprovedAt DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    IsDeleted BIT NOT NULL DEFAULT 0,
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_Transactions_Household
        FOREIGN KEY (HouseholdId) REFERENCES dbo.Households(Id),
    CONSTRAINT FK_Transactions_Creator
        FOREIGN KEY (CreatedByUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Transactions_Account
        FOREIGN KEY (AccountId) REFERENCES dbo.Accounts(Id),
    CONSTRAINT FK_Transactions_Category
        FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(Id),
    CONSTRAINT FK_Transactions_Approver
        FOREIGN KEY (ApprovedByUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Transactions_Amount CHECK (Amount > 0),
    CONSTRAINT CK_Transactions_Type CHECK ([Type] IN (0,1,2)),
    CONSTRAINT CK_Transactions_Visibility CHECK (Visibility IN (0,1,2)),
    CONSTRAINT CK_Transactions_Status CHECK ([Status] IN (0,1,2,3,4))
);

CREATE INDEX IX_Transactions_Household_Date
ON dbo.Transactions(HouseholdId, TransactionDate DESC);

CREATE INDEX IX_Transactions_Creator_Date
ON dbo.Transactions(CreatedByUserId, TransactionDate DESC);

CREATE TABLE dbo.TransactionShares (
    TransactionId UNIQUEIDENTIFIER NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    SharedByUserId UNIQUEIDENTIFIER NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_TransactionShares
        PRIMARY KEY (TransactionId, UserId),
    CONSTRAINT FK_TransactionShares_Transaction
        FOREIGN KEY (TransactionId) REFERENCES dbo.Transactions(Id),
    CONSTRAINT FK_TransactionShares_User
        FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_TransactionShares_SharedBy
        FOREIGN KEY (SharedByUserId) REFERENCES dbo.Users(Id)
);

CREATE TABLE dbo.ApprovalRequests (
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_ApprovalRequests PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    TransactionId UNIQUEIDENTIFIER NOT NULL,
    RequestedByUserId UNIQUEIDENTIFIER NOT NULL,
    ReviewedByUserId UNIQUEIDENTIFIER NULL,
    [Status] TINYINT NOT NULL DEFAULT 0,
    -- 0 Pending, 1 Approved, 2 Rejected
    ReviewNote NVARCHAR(1000) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ReviewedAt DATETIME2 NULL,
    CONSTRAINT FK_ApprovalRequests_Transaction
        FOREIGN KEY (TransactionId) REFERENCES dbo.Transactions(Id),
    CONSTRAINT FK_ApprovalRequests_Requester
        FOREIGN KEY (RequestedByUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_ApprovalRequests_Reviewer
        FOREIGN KEY (ReviewedByUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT UQ_ApprovalRequests_Transaction UNIQUE (TransactionId),
    CONSTRAINT CK_ApprovalRequests_Status CHECK ([Status] IN (0,1,2))
);

CREATE TABLE dbo.Budgets (
    Id UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT PK_Budgets PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    HouseholdId UNIQUEIDENTIFIER NULL,
    CreatedByUserId UNIQUEIDENTIFIER NOT NULL,
    CategoryId UNIQUEIDENTIFIER NULL,
    Name NVARCHAR(150) NOT NULL,
    LimitAmount DECIMAL(18,2) NOT NULL,
    Period TINYINT NOT NULL, -- 0 Monthly, 1 Weekly, 2 Yearly
    Mode TINYINT NOT NULL,   -- 0 Planned, 1 Active
    Priority TINYINT NOT NULL DEFAULT 1,
    StartDate DATE NOT NULL,
    EndDate DATE NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Budgets_Household
        FOREIGN KEY (HouseholdId) REFERENCES dbo.Households(Id),
    CONSTRAINT FK_Budgets_Creator
        FOREIGN KEY (CreatedByUserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Budgets_Category
        FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(Id),
    CONSTRAINT CK_Budgets_Limit CHECK (LimitAmount > 0),
    CONSTRAINT CK_Budgets_Period CHECK (Period IN (0,1,2)),
    CONSTRAINT CK_Budgets_Mode CHECK (Mode IN (0,1)),
    CONSTRAINT CK_Budgets_Priority CHECK (Priority IN (0,1,2))
);