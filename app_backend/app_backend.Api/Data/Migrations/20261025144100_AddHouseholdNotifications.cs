using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace app_backend.Api.Data.Migrations;

public sealed partial class AddHouseholdNotifications : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "HouseholdNotifications",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "NEWSEQUENTIALID()"),
                HouseholdId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                RecipientUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Title = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                Message = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                ReadAt = table.Column<DateTime>(type: "datetime2", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_HouseholdNotifications", x => x.Id);
                table.ForeignKey(
                    name: "FK_HouseholdNotifications_Households_HouseholdId",
                    column: x => x.HouseholdId,
                    principalTable: "Households",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
                table.ForeignKey(
                    name: "FK_HouseholdNotifications_Users_RecipientUserId",
                    column: x => x.RecipientUserId,
                    principalTable: "Users",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateIndex(
            name: "IX_HouseholdNotifications_RecipientUserId_ReadAt_CreatedAt",
            table: "HouseholdNotifications",
            columns: new[] { "RecipientUserId", "ReadAt", "CreatedAt" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "HouseholdNotifications");
    }
}
