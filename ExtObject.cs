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

using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Xml;
using System.Xml.Serialization;
using System.Xml.XPath;

namespace XsltEngineDemo
{
    public class ExtObject
    {
        private String claimsServiceUri;

        public ExtObject(String claimsServiceUri)
        {
            this.claimsServiceUri = claimsServiceUri;
        }

        public double Circumference(double radius)
        {
            // perform a local calculation.
            double pi = 3.14159;
            double circ = pi * radius * 2;
            return circ;
        }

        public string Timestamp()
        {
            // return something from the environment (a timestamp)
            return DateTime.UtcNow.ToString("s", System.Globalization.CultureInfo.InvariantCulture);
        }

        // Return XPathNodeIterator with a node set.
        // https://learn.microsoft.com/en-us/previous-versions/bb986125(v=msdn.10)?redirectedfrom=MSDN
        public XPathNodeIterator ProcessClaim(String procedureCode, Double amount, String patientId)
        {
            var payload = new Claim(patientId, amount, procedureCode);

            // call out to the remote Rules Engine.
            using (var client = new HttpClient())
            {
                var request = new HttpRequestMessage()
                {
                    RequestUri = new Uri(this.claimsServiceUri + "/claims"),
                    Method = HttpMethod.Post,
                };

                request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                request.Content = new StringContent(
                    JsonSerializer.Serialize(payload),
                    Encoding.UTF8,
                    "application/json"
                ); //CONTENT-TYPE header

                var response = client.Send(request);
                var responseContent = response.Content.ReadAsStringAsync().Result;
                // Console.WriteLine($"response: ");
                // Console.WriteLine($" status: {response.StatusCode}");
                // Console.WriteLine($" headers: {JsonSerializer.Serialize(response.Headers)}");
                // Console.WriteLine($" json content: {responseContent}");

                // convert JSON to XML
                var options = new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                    PropertyNameCaseInsensitive = true,
                };

                Claim processedClaim =
                    JsonSerializer.Deserialize<Claim>(responseContent, options)
                    ?? throw new Exception("cannot deserialize");

                // use XmlSerializer - for some reason this is not working
                XmlSerializer xmlSerializer = new XmlSerializer(processedClaim.GetType());
                using (StringWriter textWriter = new StringWriter())
                {
                    XmlSerializerNamespaces xmlns = new XmlSerializerNamespaces();
                    xmlns.Add("", "");
                    xmlSerializer.Serialize(textWriter, processedClaim, xmlns);
                    responseContent = textWriter.ToString();
                    Console.WriteLine($" xml content: {responseContent}");
                }

                XmlDocument doc = new XmlDocument();
                XmlElement root = doc.CreateElement("result");
                root.InnerXml = responseContent;
                doc.AppendChild(root);
                return doc.CreateNavigator().Select("result/*");
            }
        }
    }
}
