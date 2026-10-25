using app_backend.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace app_backend.Api.Data;

public sealed class FinanceManagerDbContext(DbContextOptions<FinanceManagerDbContext> options)
    : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Household> Households => Set<Household>();
    public DbSet<HouseholdMember> HouseholdMembers => Set<HouseholdMember>();
    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<Transaction> Transactions => Set<Transaction>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<TransactionShare> TransactionShares => Set<TransactionShare>();
    public DbSet<ApprovalRequest> ApprovalRequests => Set<ApprovalRequest>();
    public DbSet<Budget> Budgets => Set<Budget>();
    public DbSet<HouseholdNotification> HouseholdNotifications => Set<HouseholdNotification>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.Entity<User>(e => {
            e.ToTable("Users"); e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");
            e.Property(x => x.FirebaseUid).HasMaxLength(128).IsRequired();
            e.HasIndex(x => x.FirebaseUid).IsUnique();
            e.Property(x => x.Email).HasMaxLength(320);
            e.Property(x => x.DisplayName).HasMaxLength(150).IsRequired();
            e.Property(x => x.CreatedAt).HasDefaultValueSql("SYSUTCDATETIME()");
            e.Property(x => x.IsActive).HasDefaultValue(true);
        });
        modelBuilder.Entity<Household>(e => {
            e.ToTable("Households", t => t.HasCheckConstraint("CK_Households_Threshold", "[ApprovalThreshold] >= 0")); e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");
            e.Property(x => x.Name).HasMaxLength(150).IsRequired();
            e.Property(x => x.ApprovalThreshold).HasPrecision(18,2);
            e.Property(x => x.ApprovalThreshold).HasDefaultValue(1000000m);
            e.Property(x => x.CreatedAt).HasDefaultValueSql("SYSUTCDATETIME()");
            e.Property(x => x.IsActive).HasDefaultValue(true);
            e.HasOne(x => x.CreatedByUser).WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<HouseholdMember>(e => {
            e.ToTable("HouseholdMembers", t => {
                t.HasCheckConstraint("CK_HouseholdMembers_Role", "[Role] IN (0,1,2)");
                t.HasCheckConstraint("CK_HouseholdMembers_Status", "[Status] IN (0,1,2)");
            }); e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");
            e.HasIndex(x => new { x.HouseholdId, x.UserId }).IsUnique();
            e.Property(x => x.Role).HasConversion<byte>(); e.Property(x => x.Status).HasConversion<byte>();
            e.Property(x => x.Status)
                .HasDefaultValue(MemberStatus.Active)
                .HasSentinel((MemberStatus)byte.MaxValue);
            e.HasIndex(x => x.UserId).IsUnique().HasFilter("[Status] = 1").HasDatabaseName("UX_HouseholdMembers_OneActiveHousehold");
            e.Property(x => x.CanViewIncomeDetails).HasDefaultValue(false);
            e.Property(x => x.CanApproveExpenses).HasDefaultValue(false);
            e.HasOne(x => x.Household).WithMany(x => x.Members).HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<HouseholdNotification>(e => {
            e.ToTable("HouseholdNotifications"); e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");
            e.Property(x => x.Title).HasMaxLength(150).IsRequired();
            e.Property(x => x.Message).HasMaxLength(500).IsRequired();
            e.Property(x => x.CreatedAt).HasDefaultValueSql("SYSUTCDATETIME()");
            e.HasIndex(x => new { x.RecipientUserId, x.ReadAt, x.CreatedAt });
            e.HasOne(x => x.Household).WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.RecipientUser).WithMany().HasForeignKey(x => x.RecipientUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Account>(e => {
            e.ToTable("Accounts"); e.HasKey(x => x.Id); e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");
            e.Property(x => x.Type).HasConversion<byte>(); e.Property(x => x.OpeningBalance).HasPrecision(18,2);
            e.Property(x => x.OpeningBalance).HasDefaultValue(0m);
            e.Property(x => x.IsDemo).HasDefaultValue(true);
            e.Property(x => x.IsActive).HasDefaultValue(true);
            e.Property(x => x.CreatedAt).HasDefaultValueSql("SYSUTCDATETIME()");
            e.HasOne(x => x.OwnerUser).WithMany().HasForeignKey(x => x.OwnerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Household).WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Category>(e => {
            e.ToTable("Categories", t => t.HasCheckConstraint("CK_Categories_Type", "[Type] IN (0,1)")); e.HasKey(x => x.Id); e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");
            e.Property(x => x.Type).HasConversion<byte>();
            e.Property(x => x.IsSystem).HasDefaultValue(false);
            e.Property(x => x.IsActive).HasDefaultValue(true);
            e.HasIndex(x => new { x.Name, x.Type });
        });
        modelBuilder.Entity<Transaction>(e => {
            e.ToTable("Transactions", t => {
                t.HasCheckConstraint("CK_Transactions_Amount", "[Amount] > 0");
                t.HasCheckConstraint("CK_Transactions_Type", "[Type] IN (0,1,2)");
                t.HasCheckConstraint("CK_Transactions_Visibility", "[Visibility] IN (0,1,2)");
                t.HasCheckConstraint("CK_Transactions_Status", "[Status] IN (0,1,2,3,4)");
            }); e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");
            e.Property(x => x.Type).HasConversion<byte>(); e.Property(x => x.Visibility).HasConversion<byte>(); e.Property(x => x.Status).HasConversion<byte>();
            e.Property(x => x.Amount).HasPrecision(18,2); e.Property(x => x.Note).HasMaxLength(1000); e.Property(x => x.RowVersion).IsRowVersion();
            e.Property(x => x.Visibility).HasDefaultValue(TransactionVisibility.Private);
            e.Property(x => x.Status).HasDefaultValue(TransactionStatus.Draft);
            e.Property(x => x.RequiresApproval).HasDefaultValue(false);
            e.Property(x => x.CreatedAt).HasDefaultValueSql("SYSUTCDATETIME()");
            e.Property(x => x.IsDeleted).HasDefaultValue(false);
            e.HasIndex(x => new { x.HouseholdId, x.TransactionDate }).HasDatabaseName("IX_Transactions_Household_Date");
            e.HasIndex(x => new { x.CreatedByUserId, x.TransactionDate }).HasDatabaseName("IX_Transactions_Creator_Date");
            e.HasOne(x => x.Household).WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.CreatedByUser).WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Account).WithMany().HasForeignKey(x => x.AccountId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Category).WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.ApprovedByUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<TransactionShare>(e => {
            e.ToTable("TransactionShares"); e.HasKey(x => new { x.TransactionId, x.UserId });
            e.Property(x => x.CreatedAt).HasDefaultValueSql("SYSUTCDATETIME()");
            e.HasOne(x => x.Transaction).WithMany().HasForeignKey(x => x.TransactionId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.SharedByUser).WithMany().HasForeignKey(x => x.SharedByUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<ApprovalRequest>(e => {
            e.ToTable("ApprovalRequests", t => t.HasCheckConstraint("CK_ApprovalRequests_Status", "[Status] IN (0,1,2)")); e.HasKey(x => x.Id); e.HasIndex(x => x.TransactionId).IsUnique();
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");
            e.Property(x => x.Status).HasConversion<byte>(); e.Property(x => x.ReviewNote).HasMaxLength(1000);
            e.Property(x => x.Status).HasDefaultValue(ApprovalStatus.Pending);
            e.Property(x => x.CreatedAt).HasDefaultValueSql("SYSUTCDATETIME()");
            e.HasOne(x => x.Transaction).WithMany().HasForeignKey(x => x.TransactionId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.RequestedByUser).WithMany().HasForeignKey(x => x.RequestedByUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.ReviewedByUser).WithMany().HasForeignKey(x => x.ReviewedByUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Budget>(e =>
        {
            e.ToTable("Budgets", t => {
                t.HasCheckConstraint("CK_Budgets_Limit", "[LimitAmount] > 0");
                t.HasCheckConstraint("CK_Budgets_Period", "[Period] IN (0,1,2)");
                t.HasCheckConstraint("CK_Budgets_Mode", "[Mode] IN (0,1)");
                t.HasCheckConstraint("CK_Budgets_Priority", "[Priority] IN (0,1,2)");
            });
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasDefaultValueSql("NEWSEQUENTIALID()");

            e.Property(x => x.Name)
                .HasMaxLength(150)
                .IsRequired();

            e.Property(x => x.LimitAmount)
                .HasPrecision(18, 2);

            e.Property(x => x.Period).HasConversion<byte>();
            e.Property(x => x.Mode).HasConversion<byte>();
            e.Property(x => x.Priority).HasConversion<byte>();
            e.Property(x => x.Priority)
                .HasDefaultValue(BudgetPriority.Normal)
                .HasSentinel((BudgetPriority)byte.MaxValue);

            e.Property(x => x.StartDate).HasColumnType("date");
            e.Property(x => x.EndDate).HasColumnType("date");
            e.Property(x => x.IsActive).HasDefaultValue(true);
            e.Property(x => x.CreatedAt).HasDefaultValueSql("SYSUTCDATETIME()");

            // Khai báo quan hệ rõ ràng với các navigation property hiện có.
            e.HasOne(x => x.Household)
                .WithMany()
                .HasForeignKey(x => x.HouseholdId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(x => x.CreatedByUser)
                .WithMany()
                .HasForeignKey(x => x.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(x => x.Category)
                .WithMany()
                .HasForeignKey(x => x.CategoryId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
