using System.Globalization;

namespace Middleware;

public class ResponseHeaderInjection
{
    private readonly RequestDelegate _next;
    private readonly String _serviceName;
    private readonly String _buildTime;

    public ResponseHeaderInjection(RequestDelegate next, String serviceName)
    {
        _next = next;
        _serviceName = serviceName;
        _buildTime = cmdwtf.BuildTimestamp.BuildTimeUtc.ToString(
            "o",
            System.Globalization.CultureInfo.InvariantCulture
        );
    }

    public async Task InvokeAsync(HttpContext context)
    {
        context.Response.OnStarting(() =>
        {
            context.Response.Headers.Append("Build-Time", _buildTime);
            context.Response.Headers.Append(
                "service",
                String.Format(
                    "{0} {1}",
                    _serviceName,
                    (Environment.GetEnvironmentVariable("K_REVISION") != null)
                        ? $"{Environment.GetEnvironmentVariable("K_REVISION")}"
                        : "xx"
                )
            );
            return Task.CompletedTask;
        });

        // Call the next delegate/middleware in the pipeline.
        await _next(context);
    }
}
