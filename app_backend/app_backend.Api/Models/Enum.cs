namespace app_backend.Api.Models;

public enum MemberRole : byte
{
    Owner = 0,
    Admin = 1,
    Member = 2
}

public enum MemberStatus : byte
{
    Invited = 0,
    Active = 1,
    Left = 2
}

public enum TransactionType : byte
{
    Expense = 0,
    Income = 1,
    Transfer = 2
}

public enum TransactionVisibility : byte
{
    Private = 0,
    Household = 1,
    SelectedMembers = 2
}

public enum TransactionStatus : byte
{
    Draft = 0,
    PendingApproval = 1,
    Approved = 2,
    Rejected = 3,
    Cancelled = 4
}

public enum ApprovalStatus : byte
{
    Pending = 0,
    Approved = 1,
    Rejected = 2
}

public enum AccountType : byte
{
    Cash = 0,
    BankDemo = 1,
    EWalletDemo = 2
}

public enum BudgetPeriod : byte
{
    Weekly = 1,
    Monthly = 0,
    Yearly = 2
}

public enum BudgetMode : byte
{
    Planned = 0,
    Active = 1
}

public enum BudgetPriority : byte
{
    Low = 0,
    Normal = 1,
    High = 2
}


public enum CategoryType : byte
{
    Expense = 0,
    Income = 1
}
