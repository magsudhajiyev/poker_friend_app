# Poker Friend - Styling Guide

## Overview
Poker Friend is a mobile-first poker tracking application built with React, TypeScript, and Tailwind CSS. The design follows a dark theme with elegant card layouts and vibrant accent colors.

## Design System

### Color Palette
The application uses a semantic color system defined in `src/index.css`:

```css
:root {
  /* Health/Poker Theme Colors */
  --health-bg: 220 13% 9%;           /* Dark background */
  --health-card: 220 13% 11%;        /* Card backgrounds */
  --health-text: 220 9% 95%;         /* Primary text */
  --health-muted: 220 9% 60%;        /* Secondary text */
  --health-primary: 142 69% 58%;     /* Green accent (progress, primary actions) */
  
  /* Metric-specific colors */
  --health-glucose: 217 91% 60%;     /* Blue for sessions */
  --health-pill: 262 83% 58%;        /* Purple for win rate */
  --health-activity: 142 69% 58%;    /* Green for hours */
  --health-carbs: 25 95% 53%;        /* Orange for streaks */
}
```

### Typography
- **Primary Font**: System font stack for optimal performance
- **Headings**: Bold weights (font-bold, font-semibold)
- **Body Text**: Regular weight
- **Sizes**: Responsive scale from text-sm to text-2xl

### Component Architecture

#### Layout Structure
```
Index (Main Dashboard)
├── Header Section
│   ├── Greeting + Date
│   └── Notification Bell
├── Goal Progress Card
│   ├── Bankroll Progress
│   └── Circular Progress Indicator
├── Metrics Grid (2x2)
│   ├── Sessions Played
│   ├── Win Rate
│   ├── Hours Played
│   └── Win Streak
├── Earnings Chart
│   └── Tournament vs Cash Game
└── Bottom Navigation
```

#### Card Design Pattern
All cards follow a consistent design:
- **Background**: `bg-health-card`
- **Border Radius**: `rounded-2xl` or `rounded-3xl`
- **Padding**: `p-4` (metrics) or `p-6` (main cards)
- **Min Height**: `min-h-[100px]` for metric cards

```tsx
// Standard card pattern
<div className="bg-health-card rounded-2xl p-6">
  {/* Card content */}
</div>
```

## Component Guidelines

### MetricCard Component
```tsx
interface MetricCardProps {
  title: string;          // Metric name
  value: string;          // Main value to display
  unit?: string;          // Optional unit (%, games, etc.)
  icon?: ReactNode;       // Legacy icon support
  iconImage?: string;     // 3D icon image path
  iconColor?: string;     // Icon tint color
}
```

**Usage Pattern**:
- Title in top-left
- Icon in top-right (3D image preferred)
- Large value with small unit below

### CircularProgress Component
- Used for goal tracking (bankroll progress)
- Configurable size, stroke width, and progress value
- Centers percentage text and optional icon overlay

### Chart Components
- Uses Recharts library with custom theming
- Consistent color mapping to design tokens
- Responsive container for mobile optimization

## Icon System

### 3D Icons
The application uses custom-generated 3D isometric icons stored in `src/assets/`:
- `sessions-icon.png` - Golden poker chip
- `winrate-icon.png` - Trophy with percentage
- `hours-icon.png` - Blue clock
- `streak-icon.png` - Orange flame
- `bankroll-icon.png` - Green money stack

**Icon Usage**:
```tsx
import iconImage from '../assets/icon-name.png';

// In JSX
<img src={iconImage} alt="Description" className="w-5 h-5 object-contain" />
```

## Responsive Design

### Mobile-First Approach
- **Container**: `max-w-sm mx-auto px-6` (centered, mobile-optimized)
- **Grid**: `grid-cols-2` for metrics
- **Spacing**: Consistent `gap-4` and `mb-6` patterns

### Breakpoints
Built for mobile primarily, with responsive scaling:
- Default: Mobile (320px+)
- sm: Small tablets (640px+)
- md: Tablets (768px+)

## Spacing System

### Consistent Spacing Scale
- **xs**: `gap-1`, `mb-1` (4px)
- **sm**: `gap-2`, `mb-2` (8px)
- **md**: `gap-4`, `mb-4` (16px)
- **lg**: `gap-6`, `mb-6` (24px)
- **xl**: `gap-8`, `mb-8` (32px)

### Layout Margins
- **Container padding**: `px-6 py-8`
- **Card spacing**: `mb-6`
- **Element gaps**: `gap-4` (grid), `gap-2` (inline elements)

## Animation Guidelines

### Smooth Transitions
```css
/* Standard transition for interactive elements */
transition-all duration-300 ease-in-out

/* Progress animations */
transition-all duration-500 ease-in-out
```

### Hover States
- Cards: Subtle scale or shadow effects
- Buttons: Background color changes
- Icons: Slight scale or color transitions

## Chart Styling

### Recharts Configuration
```tsx
// Consistent axis styling
<XAxis 
  axisLine={false}
  tickLine={false}
  tick={{ fontSize: 12, fill: 'hsl(var(--health-muted))' }}
/>

// Line styling with design tokens
<Line 
  stroke="hsl(var(--health-primary))" 
  strokeWidth={3}
  dot={{ fill: 'hsl(var(--health-primary))', r: 4 }}
/>
```

## Best Practices

### Color Usage
1. **Never use direct colors** like `text-white`, `bg-black`
2. **Always use semantic tokens** from the design system
3. **Maintain contrast** between text and backgrounds
4. **Use HSL format** for all custom colors

### Component Structure
1. **Keep components focused** - single responsibility
2. **Use TypeScript interfaces** for all props
3. **Import assets as ES6 modules**
4. **Maintain consistent prop patterns**

### Performance
1. **Optimize images** - use appropriate sizes
2. **Lazy load** non-critical assets
3. **Use semantic HTML** for accessibility
4. **Minimize re-renders** with proper React patterns

## File Structure
```
src/
├── assets/           # 3D icons and images
├── components/       # Reusable UI components
│   ├── ui/          # Shadcn/ui components
│   ├── MetricCard.tsx
│   ├── CircularProgress.tsx
│   └── BloodSugarChart.tsx
├── pages/           # Route components
└── lib/             # Utilities
```

## Future Enhancements

### Planned Features
- Dark/light mode toggle
- Additional chart types
- Real-time data integration
- Advanced animations

### Scalability Considerations
- Consistent design token usage enables easy theming
- Component-based architecture supports feature additions
- Mobile-first approach ensures performance
- TypeScript provides type safety for large teams

---

This guide should be updated as the design system evolves and new components are added to the project.