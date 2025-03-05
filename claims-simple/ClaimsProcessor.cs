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

namespace ClaimsXsltDemo;

public class ClaimsProcessor
{
    private int claimIdNumber = 0;

    public string Timestamp()
    {
        // return something from the environment (a timestamp)
        return DateTime.UtcNow.ToString("s", System.Globalization.CultureInfo.InvariantCulture);
    }

    /**
     * Call out to the remote Rules Engine.
     * Return XPathNodeIterator with a node set.
     * see https://learn.microsoft.com/en-us/previous-versions/bb986125(v=msdn.10)?redirectedfrom=MSDN
     ***/
    public XPathNodeIterator ProcessClaim(String procedureCode, Double amount, String patientId)
    {
        var processedClaim = new Claim(patientId, amount, procedureCode);
        processedClaim.Id = Interlocked.Increment(ref claimIdNumber);
        if (procedureCode == "142007")
        {
            if (amount < 250)
            {
                processedClaim.Approve();
            }
            else if (amount < 300)
            {
                processedClaim.ApproveWithNote("with surcharge");
            }
            else
            {
                processedClaim.Reject("Exceeds amount for Procedure 142007");
            }
        }
        else if (procedureCode == "166001")
        {
            if (amount < 180)
            {
                processedClaim.Approve();
            }
            else if (amount <= 200)
            {
                processedClaim.ApproveWithNote("requires additional documentation");
            }
            else
            {
                processedClaim.Reject("Not Approved");
            }
        }
        else if (procedureCode == "628003")
        {
            processedClaim.Reject("Explicitly Not Covered");
        }

        String? responseContent;
        XmlSerializer xmlSerializer = new XmlSerializer(processedClaim.GetType());
        using (StringWriter textWriter = new StringWriter())
        {
            XmlSerializerNamespaces xmlns = new XmlSerializerNamespaces();
            xmlns.Add("", "");
            xmlSerializer.Serialize(textWriter, processedClaim, xmlns);
            responseContent = textWriter.ToString();
            //Console.WriteLine($" xml content: {responseContent}");
        }

        XmlDocument doc = new XmlDocument();
        XmlElement root = doc.CreateElement("result");
        root.InnerXml = responseContent;
        doc.AppendChild(root);
        var nav = doc.CreateNavigator() ?? throw new Exception("cannot create Navigator");

        return nav.Select("result/*");
    }
}
