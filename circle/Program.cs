// Copyright © 2024,2025 Google LLC.
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

namespace CircleXsltDemo
{
    public static class Program
    {
        private const String DEFAULT_STYLESHEET = "stylesheet1.xsl";
        private const String SERVICE_NAME = "circle-xslt-service";

        public static void Main(string[] args)
        {
            try
            {
                Console.Error.WriteLine($"${SERVICE_NAME} Starting up...");
                String buildTime = cmdwtf.BuildTimestamp.BuildTimeUtc.ToString(
                    "o",
                    System.Globalization.CultureInfo.InvariantCulture
                );
                Console.Error.WriteLine($"Build time: {buildTime}");

                // Disable QUIC / H3 - it is not currently permitted in Cloud Run.
                //
                // .NET 8 and .NET 9 has HTTP/3 enabled as a
                // default whereas Cloud Run supports HTTP/1 or HTTP/2 only.
                //
                // refer to: https://github.com/dotnet/runtime/issues/94794
                AppContext.SetSwitch("System.Net.SocketsHttpHandler.Http3Support", false);

                var configPath =
                    Environment.GetEnvironmentVariable($"APP_CONFIG")
                    ?? Environment.CurrentDirectory;

                var files = Directory.GetFiles(
                    configPath,
                    DEFAULT_STYLESHEET,
                    SearchOption.AllDirectories
                );

                if (files == null || files.Length == 0)
                    throw new FileNotFoundException("Stylesheet not found.");

                var app = XsltDemo.XsltWebApp.CreateApp(
                    SERVICE_NAME,
                    files[0],
                    "urn:geometry",
                    new GeometryCalculator(),
                    args
                );

                var port = Environment.GetEnvironmentVariable("PORT") ?? "9090";
                var url = $"http://0.0.0.0:{port}";
                app.Run(url);
            }
            catch (Exception e)
            {
                Console.Error.WriteLine(e.ToString());
            }
        }
    }
}
