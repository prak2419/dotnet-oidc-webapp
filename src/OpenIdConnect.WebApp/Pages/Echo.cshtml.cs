using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Logging;

namespace OpenIdConnect.WebApp.Pages
{
    [AllowAnonymous]
    public class EchoModel : PageModel
    {
        private readonly ILogger _logger;

        public EchoModel(ILogger<EchoModel> logger)
        {
            _logger = logger;
        }

        public void OnGet()
        {
        }
    }
}
