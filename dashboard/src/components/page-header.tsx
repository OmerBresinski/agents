import { cn } from '@/lib/utils';

interface PageHeaderProps {
  title: string;
  description: string;
  className?: string;
}

export function PageHeader({ title, description, className }: PageHeaderProps) {
  return (
    <div className={cn('border-b border-border bg-card px-6 py-5', className)}>
      <h1 className="animate-[fadeSlideIn_0.3s_ease-out_both] font-heading text-2xl font-normal tracking-tight">
        {title}
      </h1>
      <p className="mt-0.5 animate-[fadeSlideIn_0.3s_ease-out_0.08s_both] text-sm text-muted-foreground">
        {description}
      </p>
    </div>
  );
}
