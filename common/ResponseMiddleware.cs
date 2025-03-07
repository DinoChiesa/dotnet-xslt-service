// Copyright © 2025 Google LLC.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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
