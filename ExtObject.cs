namespace XsltEngineDemo
{
    public class ExtObject
    {
        public double Circumference(double radius)
        {
            // Theoretically this method could call out to the remote Rules Engine.
            // For this illustration, it simply performs a calculation.
            double pi = 3.14159;
            double circ = pi * radius * 2;
            return circ;
        }

        public string Timestamp()
        {
            return DateTime.UtcNow.ToString("s", System.Globalization.CultureInfo.InvariantCulture);
        }
    }
}
