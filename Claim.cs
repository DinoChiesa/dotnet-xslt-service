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

using System.Xml.Serialization;

namespace XsltEngineDemo
{
    [XmlRoot(ElementName = "claim")]
    public class Claim
    {
        [XmlElement(ElementName = "id")]
        public int Id { get; set; }

        [XmlElement(ElementName = "amount")]
        public Double Amount { get; set; }

        [XmlElement(ElementName = "procedureCode")]
        public string? ProcedureCode { get; set; }

        [XmlElement(ElementName = "patientId")]
        public string? PatientId { get; set; }

        [XmlElement(ElementName = "isApproved")]
        public bool IsApproved { get; set; }

        [XmlElement(ElementName = "reason")]
        public string? Reason { get; set; }

        public Claim()
        {
            this.Reason = String.Empty;
        }

        public Claim(String patientId, double amount, string procedureCode)
        {
            this.PatientId = patientId;
            this.Amount = amount;
            this.ProcedureCode = procedureCode;
            this.Reason = String.Empty;
        }

        public void Approve()
        {
            this.IsApproved = true;
        }

        public void Reject(string reason)
        {
            this.Reason = reason;
        }
    }
}
