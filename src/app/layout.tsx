import type { Metadata, Viewport } from "next";
import { AppProvider } from "@/components/providers/app-provider";
import { Toaster } from "@/components/ui/sonner";
import "./globals.css";

export const metadata: Metadata = {
  title: "CheckMoney — personal money tracker",
  description:
    "Track expenses and income with manual or voice entry. Local-only, iOS-inspired.",
  appleWebApp: {
    capable: true,
    title: "CheckMoney",
    statusBarStyle: "default",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#eef2f7" },
    { media: "(prefers-color-scheme: dark)", color: "#000000" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ru" className="h-full antialiased">
      <body className="min-h-full font-[family-name:var(--font-ios)]">
        <AppProvider>
          {children}
          <Toaster position="top-center" richColors closeButton />
        </AppProvider>
      </body>
    </html>
  );
}
