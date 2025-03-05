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
    public class GeometryCalculator
    {
        public string Timestamp()
        {
            // return something from the environment (a timestamp)
            return DateTime.UtcNow.ToString("s", System.Globalization.CultureInfo.InvariantCulture);
        }

        public double Circumference(double radius)
        {
            // perform a local calculation.
            double pi = 3.14159;
            double circ = pi * radius * 2;
            return circ;
        }
    }
}
