using System;
using System.IO;
using System.Text;
using System.Xml;
using System.Xml.Serialization;
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
                    throw new Exception("Stylesheet not found.");

                //string fullPath = Path.GetFullPath(stylesheet);
                xslt.Load(files[0], xsltSettings, new XmlUrlResolver());

                // Create an XsltArgumentList, to Add an object to the XSLT
                XsltArgumentList xslArglist = new XsltArgumentList();
                ExtObject obj = new ExtObject();
                xslArglist.AddExtensionObject("urn:extension1", obj);

                // create the web app
                var builder = WebApplication.CreateBuilder(args);
                var app = builder.Build();

                // inject a response header containing the build time
                app.Use(
                    async (context, next) =>
                    {
                        context.Response.OnStarting(() =>
                        {
                            context.Response.Headers.Append("Build-Time", buildTime);
                            return Task.CompletedTask;
                        });

                        await next();
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

                            // Create an XmlWriter
                            XmlWriterSettings settings = new XmlWriterSettings();
                            settings.OmitXmlDeclaration = true;
                            settings.Indent = true;

                            using (TextWriter textWriter = new Utf8StringWriter())
                            {
                                using (XmlWriter xmlWriter = XmlWriter.Create(textWriter, settings))
                                {
                                    // Execute the transformation
                                    xslt.Transform(doc, xslArglist, textWriter);
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
