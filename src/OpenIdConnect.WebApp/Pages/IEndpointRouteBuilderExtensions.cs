using System;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;

namespace OpenIdConnect.WebApp
{
    public static class IEndpointRouteBuilderExtensions
    {
        public static IEndpointConventionBuilder AddKubernetesProbes(
            this IEndpointRouteBuilder endpoints,
            int probePort)
        {
            if (endpoints is null)
            {
                throw new ArgumentNullException(nameof(endpoints));
            }

            string host = $"*:{(probePort > 0 ? $"{probePort}" : "*")}";
            var allowAnonymous = new AllowAnonymousAttribute();

            endpoints
                .MapHealthChecks("healthz/ready")
                .RequireHost(host)
                .WithMetadata(allowAnonymous);
            return endpoints
                .MapHealthChecks("healthz/live")
                .RequireHost(host)
                .WithMetadata(allowAnonymous);
        }
    }
}