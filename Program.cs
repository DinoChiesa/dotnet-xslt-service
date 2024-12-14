// Copyright © 2024 Google LLC.
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

using System;
using System.IO;
using System.Text;
using System.Xml;
using System.Xml.XPath;
using System.Xml.Xsl;

namespace XsltEngineDemo
{
    public class Utf8StringWriter : StringWriter
    {
        public override Encoding Encoding
        {
            get { return Encoding.UTF8; }
        }
    }

    public static class Program
    {
        private const String DEFAULT_STYLESHEET = "stylesheet1.xsl";

        public static void Main(string[] args)
        {
            try
            {
                Console.Error.WriteLine($"xslt-service Starting up...");
                String buildTime = cmdwtf.BuildTimestamp.BuildTimeUtc.ToString(
                    "o",
                    System.Globalization.CultureInfo.InvariantCulture
                );
                Console.Error.WriteLine($"Build time: {buildTime}");

                // Disable QUIC / H3 (apparently not permitted in Cloud run)l
                //
                // It seems like .NET 8 or .NET 9 has HTTP/3 enabled as a
                // default whereas Cloud Run supports HTTP/1 or HTTP/2 only.
                AppContext.SetSwitch("System.Net.SocketsHttpHandler.Http3Support", false);

                // Compile the style sheet
                XsltSettings xsltSettings = new XsltSettings();
                xsltSettings.EnableScript = true;
                XslCompiledTransform xslt = new XslCompiledTransform();

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

                xslt.Load(files[0], xsltSettings, new XmlUrlResolver());

                // create the web app
                var builder = WebApplication.CreateBuilder(args);
                var claimsServiceUri = getClaimsServiceUri(builder);

                // An XsltArgumentList allows us to make an object accessible to the XSLT.
                XsltArgumentList xslArglist = new XsltArgumentList();
                ExtObject obj = new ExtObject(claimsServiceUri);
                xslArglist.AddExtensionObject("urn:extension1", obj);

                var app = builder.Build();

                // Always inject a response header containing the build time.
                app.Use(
                    async (context, next) =>
                    {
                        context.Response.OnStarting(() =>
                        {
                            context.Response.Headers.Append("Build-Time", buildTime);
                            context.Response.Headers.Append(
                                "service",
                                (Environment.GetEnvironmentVariable("K_REVISION") != null)
                                    ? $"{Environment.GetEnvironmentVariable("K_REVISION")}"
                                    : "xslt-service"
                            );
                            return Task.CompletedTask;
                        });

                        await next();
                    }
                );

                app.MapGet(
                    "/xsl",
                    (HttpRequest request) =>
                    {
                        var fileData = File.ReadAllText(files[0]);
                        return Results.Text(fileData);
                    }
                );

                app.MapPost(
                    "/xml",
                    async (HttpRequest Request) =>
                    {
                        string rawContent = string.Empty;
                        using (
                            var reader = new StreamReader(
                                Request.Body,
                                encoding: Encoding.UTF8,
                                detectEncodingFromByteOrderMarks: false
                            )
                        )
                        {
                            rawContent = await reader.ReadToEndAsync();
                        }

                        try
                        {
                            // Load the XML source file
                            XmlDocument xmldoc = new XmlDocument();
                            xmldoc.PreserveWhitespace = true;
                            xmldoc.LoadXml(rawContent);
                            XPathDocument doc = new XPathDocument(new XmlNodeReader(xmldoc));

                            // Create an XmlWriter with the right indentation settings
                            XmlWriterSettings xmlWriterSettings = new XmlWriterSettings()
                            {
                                IndentChars = "  ",
                                OmitXmlDeclaration = true,
                                Indent = true,
                            };

                            using (var textWriter = new Utf8StringWriter())
                            {
                                using (
                                    var xmlWriter = XmlWriter.Create(textWriter, xmlWriterSettings)
                                )
                                {
                                    // Execute the transformation
                                    xslt.Transform(doc, xslArglist, xmlWriter);
                                    textWriter.Flush();
                                    rawContent = textWriter.ToString() ?? string.Empty;
                                }
                            }
                            return Results.Text(rawContent);
                        }
                        catch (Exception e1)
                        {
                            Console.Error.WriteLine(e1.ToString());
                            return Results.BadRequest();
                        }
                    }
                );

                app.MapPost(
                    "/reload",
                    () =>
                    {
                        // If this fails (for example due to bad XSL), the call
                        // will return 500 with an exception stacktrace.
                        xslt.Load(files[0], xsltSettings, new XmlUrlResolver());
                    }
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

        private static String getClaimsServiceUri(WebApplicationBuilder builder)
        {
            var section =
                builder.Configuration.GetSection("ClaimsServiceUri")
                ?? throw new Exception(
                    "Missing ClaimsServiceUri configuration in appsettings.json"
                );
            var subkey =
                (
                    Environment.GetEnvironmentVariable("K_SERVICE") != null
                    && Environment.GetEnvironmentVariable("K_REVISION") != null
                )
                    ? "Remote"
                    : "Local";
            string? uri =
                section[subkey]
                ?? throw new Exception("Missing Local configuration in appsettings.json");
            Console.WriteLine($"using Claims Service URI: {uri}");
            return uri;
        }
    }
}
