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

using System.Text;
using System.Xml;
using System.Xml.XPath;
using System.Xml.Xsl;

namespace XsltDemo;

public class XsltWebApp
{
    public class Utf8StringWriter : StringWriter
    {
        public override Encoding Encoding
        {
            get { return Encoding.UTF8; }
        }
    }

    public static Microsoft.AspNetCore.Builder.WebApplication CreateApp(
        String serviceName,
        String xslFilename,
        String extensionUri,
        Object extensionObject,
        string[] args
    )
    {
        // Compile the style sheet
        XslCompiledTransform xslt = new XslCompiledTransform();
        xslt.Load(
            xslFilename,
            null, /* xsltSettings */
            new XmlUrlResolver()
        );

        // create the web app
        var builder = WebApplication.CreateBuilder(args);

        // An XsltArgumentList allows us to make one or more objects accessible to the XSLT.
        XsltArgumentList xslArglist = new XsltArgumentList();
        // Register the given object at a specific namespace
        xslArglist.AddExtensionObject(extensionUri, extensionObject);

        var app = builder.Build();

        // Always inject a response header containing the build time.
        app.UseMiddleware<Middleware.ResponseHeaderInjection>(serviceName);

        // for diagnostic purposes only
        app.MapGet(
            "/xsl",
            (HttpRequest request) =>
            {
                var fileData = File.ReadAllText(xslFilename);
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
                        using (var xmlWriter = XmlWriter.Create(textWriter, xmlWriterSettings))
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

        // Reload the XSLT
        app.MapPost(
            "/reload",
            () =>
            {
                // If this fails (for example due to bad XSL), the call
                // will return 500 with an exception stacktrace.
                xslt.Load(
                    xslFilename,
                    null, /* xsltSettings */
                    new XmlUrlResolver()
                );
            }
        );

        return app;
    }
}
