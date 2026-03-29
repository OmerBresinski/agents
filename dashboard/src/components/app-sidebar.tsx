import { Link } from 'react-router-dom';
import { HugeiconsIcon } from '@hugeicons/react';
import {
  Analytics02Icon,
  AiBrain01Icon,
  Clock01Icon,
  BookOpen01Icon,
  Moon02Icon,
  Sun03Icon,
} from '@hugeicons/core-free-icons';
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from '@/components/ui/sidebar';
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { cn } from '@/lib/utils';

export type Page = 'dashboard' | 'agents' | 'history' | 'guide';

interface AppSidebarProps {
  currentPage: Page;
  isDark: boolean;
  onToggleTheme: () => void;
}

const navItems: { page: Page; path: string; icon: typeof AiBrain01Icon; label: string }[] = [
  { page: 'dashboard', path: '/dashboard', icon: Analytics02Icon, label: 'Dashboard' },
  { page: 'agents', path: '/agents', icon: AiBrain01Icon, label: 'Agents' },
  { page: 'history', path: '/history', icon: Clock01Icon, label: 'History' },
  { page: 'guide', path: '/guide', icon: BookOpen01Icon, label: 'Guide' },
];

export function AppSidebar({ currentPage, isDark, onToggleTheme }: AppSidebarProps) {
  return (
    <Sidebar collapsible="icon" className="border-r border-border bg-[#FAF8F7] dark:bg-[#1a1918]">
      <SidebarHeader className="flex items-center justify-center py-4">
        <Link to="/dashboard" className="font-heading text-base font-normal tracking-tight">
          oc
        </Link>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupContent>
            <SidebarMenu>
              {navItems.map((item) => (
                <SidebarMenuItem key={item.page}>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <SidebarMenuButton
                        asChild
                        isActive={currentPage === item.page}
                        className={cn(
                          currentPage === item.page && 'bg-[#F5F0EA] text-foreground dark:bg-[#2a2826]',
                        )}
                      >
                        <Link to={item.path}>
                          <HugeiconsIcon icon={item.icon} />
                          <span>{item.label}</span>
                        </Link>
                      </SidebarMenuButton>
                    </TooltipTrigger>
                    <TooltipContent side="right">{item.label}</TooltipContent>
                  </Tooltip>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter>
        <SidebarMenu>
          <SidebarMenuItem>
            <Tooltip>
              <TooltipTrigger asChild>
                <SidebarMenuButton onClick={onToggleTheme}>
                  <HugeiconsIcon icon={isDark ? Sun03Icon : Moon02Icon} />
                  <span>{isDark ? 'Light mode' : 'Dark mode'}</span>
                </SidebarMenuButton>
              </TooltipTrigger>
              <TooltipContent side="right">{isDark ? 'Light mode' : 'Dark mode'}</TooltipContent>
            </Tooltip>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  );
}
