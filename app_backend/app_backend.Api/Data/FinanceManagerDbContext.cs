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

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.Entity<User>(e => {
            e.ToTable("Users"); e.HasKey(x => x.Id);
            e.Property(x => x.FirebaseUid).HasMaxLength(128).IsRequired();
            e.HasIndex(x => x.FirebaseUid).IsUnique();
            e.Property(x => x.Email).HasMaxLength(320);
            e.Property(x => x.DisplayName).HasMaxLength(150).IsRequired();
        });
        modelBuilder.Entity<Household>(e => {
            e.ToTable("Households"); e.HasKey(x => x.Id);
            e.Property(x => x.Name).HasMaxLength(150).IsRequired();
            e.Property(x => x.ApprovalThreshold).HasPrecision(18,2);
            e.ToTable(t => t.HasCheckConstraint("CK_Households_Threshold", "[ApprovalThreshold] >= 0"));
            e.HasOne(x => x.CreatedByUser).WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<HouseholdMember>(e => {
            e.ToTable("HouseholdMembers"); e.HasKey(x => x.Id);
            e.HasIndex(x => new { x.HouseholdId, x.UserId }).IsUnique();
            e.Property(x => x.Role).HasConversion<byte>(); e.Property(x => x.Status).HasConversion<byte>();
            e.HasIndex(x => x.UserId).IsUnique().HasFilter("[Status] = 1").HasDatabaseName("UX_HouseholdMembers_OneActiveHousehold");
            e.HasOne(x => x.Household).WithMany(x => x.Members).HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Account>(e => {
            e.ToTable("Accounts"); e.HasKey(x => x.Id); e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Type).HasConversion<byte>(); e.Property(x => x.OpeningBalance).HasPrecision(18,2);
            e.HasOne(x => x.OwnerUser).WithMany().HasForeignKey(x => x.OwnerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Household).WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Category>(e => {
            e.ToTable("Categories"); e.HasKey(x => x.Id); e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Type).HasConversion<byte>(); e.HasCheckConstraint("CK_Categories_Type", "[Type] IN (0,1)");
            e.HasIndex(x => new { x.Name, x.Type });
        });
        modelBuilder.Entity<Transaction>(e => {
            e.ToTable("Transactions"); e.HasKey(x => x.Id);
            e.Property(x => x.Type).HasConversion<byte>(); e.Property(x => x.Visibility).HasConversion<byte>(); e.Property(x => x.Status).HasConversion<byte>();
            e.Property(x => x.Amount).HasPrecision(18,2); e.Property(x => x.Note).HasMaxLength(1000); e.Property(x => x.RowVersion).IsRowVersion();
            e.HasIndex(x => new { x.HouseholdId, x.TransactionDate }).HasDatabaseName("IX_Transactions_Household_Date");
            e.HasIndex(x => new { x.CreatedByUserId, x.TransactionDate }).HasDatabaseName("IX_Transactions_Creator_Date");
            e.HasCheckConstraint("CK_Transactions_Amount", "[Amount] > 0");
            e.HasOne(x => x.Household).WithMany().HasForeignKey(x => x.HouseholdId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.CreatedByUser).WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Account).WithMany().HasForeignKey(x => x.AccountId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Category).WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.ApprovedByUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<TransactionShare>(e => {
            e.ToTable("TransactionShares"); e.HasKey(x => new { x.TransactionId, x.UserId });
            e.HasOne<Transaction>().WithMany().HasForeignKey(x => x.TransactionId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.SharedByUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<ApprovalRequest>(e => {
            e.ToTable("ApprovalRequests"); e.HasKey(x => x.Id); e.HasIndex(x => x.TransactionId).IsUnique();
            e.Property(x => x.Status).HasConversion<byte>(); e.Property(x => x.ReviewNote).HasMaxLength(1000);
            e.HasOne(x => x.Transaction).WithMany().HasForeignKey(x => x.TransactionId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.RequestedByUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.ReviewedByUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Budget>(e =>
        {
            e.ToTable("Budgets");
            e.HasKey(x => x.Id);

            e.Property(x => x.Name)
                .HasMaxLength(150)
                .IsRequired();

            e.Property(x => x.LimitAmount)
                .HasPrecision(18, 2);

            e.Property(x => x.Period).HasConversion<byte>();
            e.Property(x => x.Mode).HasConversion<byte>();
            e.Property(x => x.Priority).HasConversion<byte>();

            e.Property(x => x.StartDate).HasColumnType("date");
            e.Property(x => x.EndDate).HasColumnType("date");

            e.HasCheckConstraint( "CK_Budgets_Limit", "[LimitAmount] > 0");

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
