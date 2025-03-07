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

using System.Xml;
using System.Xml.Serialization;
using System.Xml.XPath;
using Microsoft.EntityFrameworkCore;
using RulesEngineDemo;

namespace ClaimsXsltDemo;

public class ClaimsProcessor
{
    private ClaimDb db;
    private Engine rulesEngine;

    public ClaimsProcessor()
    {
        var options = new DbContextOptionsBuilder<ClaimDb>()
            .UseInMemoryDatabase(databaseName: "ClaimList")
            .Options;

        db = new ClaimDb(options);
        rulesEngine = new Engine();
    }

    public string Timestamp()
    {
        return DateTime.UtcNow.ToString("s", System.Globalization.CultureInfo.InvariantCulture);
    }

    /**
     * Call into the Rules Engine.
     * Return XPathNodeIterator with a node set.
     * see https://learn.microsoft.com/en-us/previous-versions/bb986125(v=msdn.10)?redirectedfrom=MSDN
     ***/
    public XPathNodeIterator ProcessClaim(String procedureCode, Double amount, String patientId)
    {
        var claim = new Claim(patientId, amount, procedureCode);
        db.Claims.Add(claim);
        string result = rulesEngine.Evaluate(claim);

        if (result.StartsWith("approved"))
        {
            claim.ApproveWithNote(result);
        }
        else
        {
            claim.Reject(result);
        }
        db.SaveChanges();

        String? responseContent;
        XmlSerializer xmlSerializer = new XmlSerializer(claim.GetType());
        using (StringWriter textWriter = new StringWriter())
        {
            XmlSerializerNamespaces xmlns = new XmlSerializerNamespaces();
            xmlns.Add("", "");
            xmlSerializer.Serialize(textWriter, claim, xmlns);
            responseContent = textWriter.ToString();
        }

        XmlDocument doc = new XmlDocument();
        XmlElement root = doc.CreateElement("result");
        root.InnerXml = responseContent;
        doc.AppendChild(root);
        var nav = doc.CreateNavigator() ?? throw new Exception("cannot create Navigator");

        return nav.Select("result/*");
    }
}
