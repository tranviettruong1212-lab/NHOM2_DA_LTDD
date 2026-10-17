using System.Security.Claims;
using app_backend.Api.Data;
using app_backend.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace app_backend.Api.Services;

public sealed class CurrentUserService(FinanceManagerDbContext db)
{
    public async Task<User?> GetUserAsync(ClaimsPrincipal principal, CancellationToken ct = default)
    {
        var uid = principal.FindFirstValue("user_id")
            ?? principal.FindFirstValue("sub")
            ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(uid))
            return null;
        var user = await db.Users.SingleOrDefaultAsync(x => x.FirebaseUid == uid, ct);
        if (user is not null) return user.IsActive ? user : null;

        var email = principal.FindFirstValue(ClaimTypes.Email);
        var displayName = principal.FindFirstValue(ClaimTypes.Name);
        user = new User {
            FirebaseUid = uid,
            Email = string.IsNullOrWhiteSpace(email) ? null : email,
            DisplayName = string.IsNullOrWhiteSpace(displayName) ? (email ?? "Người dùng") : displayName,
            IsActive = true
        };
        db.Users.Add(user);
        await db.SaveChangesAsync(ct);
        return user;
    }
    public Task<int> SaveAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
