using Microsoft.AspNetCore.Mvc;
namespace app_backend.Api.Controllers;

[ApiController]
public abstract class ApiControllerBase : ControllerBase
{
    protected IActionResult ServiceError(string error) => error switch
    {
        "not_found" or "category_not_found" => NotFound(new { error }),
        "forbidden" or "household_forbidden" or "shared_edit_requires_admin" or "account_not_found_or_forbidden" => Forbid(),
        "pending_approval" or "already_reviewed" => Conflict(new { error }),
        "cannot_approve_own_request" => BadRequest(new { error }),
        "invalid_amount" or "invalid_date" or "invalid_enum" or "category_type_mismatch" or "household_required" or "share_recipients_required" or "share_recipients_not_allowed" or "duplicate_share_recipient" or "share_recipient_not_member" => BadRequest(new { error }),
        _ => BadRequest(new { error })
    };
}
