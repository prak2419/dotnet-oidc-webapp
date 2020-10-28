using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Logging;

namespace OpenIdConnect.WebApp.Pages
{
    public class TokenModel : PageModel
    {
        private readonly ILogger _logger;

        public IEnumerable<Claim> Claims { get; set; }

        public TokenModel(ILogger<TokenModel> logger)
        {
            _logger = logger;
        }

        public void OnGet()
        {
            Claims = User.Claims.OrderBy(c => c.Type);
        }
    }
}
