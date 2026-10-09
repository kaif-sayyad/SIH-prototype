import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'SkillPath Family Counselling Portal',
  description: 'Informed career decisions for students and families',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        {children}
      </body>
    </html>
  );
}
