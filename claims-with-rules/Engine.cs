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

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Dynamic;
using System.IO;
using System.Text.Json;
using ClaimsXsltDemo;
using RulesEngine.Models;
using static RulesEngine.Extensions.ListofRuleResultTreeExtension;

namespace RulesEngineDemo
{
    public class Engine
    {
        protected RulesEngine.RulesEngine bre;

        public Engine()
        {
            var configPath =
                Environment.GetEnvironmentVariable($"APP_CONFIG") ?? Environment.CurrentDirectory;

            // read the rules
            var files = Directory.GetFiles(
                configPath,
                "BusinessRules.json",
                SearchOption.AllDirectories
            );
            if (files == null || files.Length == 0)
                throw new Exception("Rules not found.");

            var fileData = File.ReadAllText(files[0]);
            var workflow = JsonSerializer.Deserialize<List<Workflow>>(fileData);

            if (workflow == null)
                throw new Exception("Could not de-serialize rules.");

            bre = new RulesEngine.RulesEngine(workflow.ToArray(), null);
        }

        public string Evaluate(Claim claim)
        {
            Console.WriteLine(
                $"Evaluate claim patient({claim.PatientId}) amount({claim.Amount})...."
            );

            var inputs = new dynamic[] { claim };
            List<RuleResultTree> resultList = bre.ExecuteAllRulesAsync(
                "ApprovalRules",
                inputs
            ).Result;

            string result = "No Rule Applies";
            // if ANY succeed
            resultList.OnSuccess(
                (successEvent) =>
                {
                    Console.WriteLine($"  Success....");
                    result = successEvent;
                }
            );

            resultList.OnFail(() =>
            {
                Console.WriteLine($"  OnFail....");
            });

            Console.WriteLine($"  Result: {result}");
            return result;
        }
    }
}
