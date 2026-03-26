# AlertPopup Module - Desktop Alert with One-Click Cleanup
# Shows WPF alert when memory usage exceeds threshold

using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Media

# Alert state tracking
$script:LastAlertTime = $null
$script:AlertCooldownSeconds = 300  # 5 minutes cooldown
$script:CurrentPopupWindow = $null

<#
.SYNOPSIS
    Show desktop alert popup
.DESCRIPTION
    Displays a WPF popup window when memory usage exceeds threshold
    Includes one-click cleanup button
#>
function Show-AlertPopup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [double]$MemoryUsagePct,
        
        [Parameter(Mandatory=$false)]
        [string[]]$TopProcesses = @(),
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$CleanupAction = $null
    )
    
    # Check cooldown
    if ($script:LastAlertTime -and 
        ((Get-Date) - $script:LastAlertTime).TotalSeconds -lt $script:AlertCooldownSeconds) {
        Write-Log "INFO" "Alert cooldown active, skipping popup"
        return
    }
    
    $script:LastAlertTime = Get-Date
    
    try {
        # Check if another alert is already showing
        if ($script:CurrentPopupWindow -and $script:CurrentPopupWindow.IsLoaded) {
            Write-Log "INFO" "Alert popup already showing, skipping"
            return
        }
        
        # Create WPF window in STA thread
        $null = [System.Windows.Application]::Current
        
        $script:CurrentPopupWindow = [Window]::new()
        $script:CurrentPopupWindow.WindowStartupLocation = "CenterScreen"
        $script:CurrentPopupWindow.SizeToContent = "WidthAndHeight"
        $script:CurrentPopupWindow.ResizeMode = "NoResize"
        $script:CurrentPopupWindow.WindowStyle = "None"
        $script:CurrentPopupWindow.AllowsTransparency = $true
        $script:CurrentPopupWindow.Background = [Media.Brushes]::Transparent
        
        # Add shadow effect
        $script:CurrentPopupWindow.Effect = [System.Windows.Media.Effects.DropShadowEffect]::new()
        $script:CurrentPopupWindow.Effect.BlurRadius = 20
        $script:CurrentPopupWindow.Effect.ShadowDepth = 0
        $script:CurrentPopupWindow.Effect.Opacity = 0.4
        
        # Create main border
        $border = [Border]::new()
        $border.CornerRadius = [CornerRadius]::new(10)
        $border.Padding = [Thickness]::new(20)
        $border.Margin = [Thickness]::new(10)
        
        # Create gradient background
        $gradient = [Media.LinearGradientBrush]::new()
        $gradient.StartPoint = [Point]::new(0, 0)
        $gradient.EndPoint = [Point]::new(1, 1)
        
        $stop1 = [Media.GradientStop]::new([Media.Colors]::FromArgb(255, 45, 45, 55), 0)
        $stop2 = [Media.GradientStop]::new([Media.Colors]::FromArgb(255, 30, 30, 40), 1)
        $gradient.GradientStops.Add($stop1)
        $gradient.GradientStops.Add($stop2)
        
        $border.Background = $gradient
        $border.BorderBrush = [Media.Brushes]::Transparent
        $border.BorderThickness = [Thickness]::new(2)
        
        # Create grid layout
        $grid = [Grid]::new()
        $grid.RowDefinitions.Add([RowDefinition]::new())  # Header
        $grid.RowDefinitions.Add([RowDefinition]::new())  # Content
        $grid.RowDefinitions.Add([RowDefinition]::new())  # Actions
        $grid.Margin = [Thickness]::new(0, 0, 0, 10)
        
        # Header - Title
        $titleText = [TextBlock]::new()
        $titleText.Text = "⚠ HIGH MEMORY USAGE"
        $titleText.FontSize = 24
        $titleText.FontWeight = "Bold"
        $titleText.Foreground = [Media.Brushes]::Orange
        $titleText.Margin = [Thickness]::new(0, 0, 0, 10)
        [Grid]::SetRow($titleText, 0)
        $grid.Children.Add($titleText) | Out-Null
        
        # Content - Memory usage
        $contentStack = [StackPanel]::new()
        $contentStack.Margin = [Thickness]::new(0, 10, 0, 10)
        
        # Memory percentage
        $memoryText = [TextBlock]::new()
        $memoryText.Text = "Memory Usage: $($MemoryUsagePct.ToString('F1'))%"
        $memoryText.FontSize = 18
        $memoryText.FontWeight = "SemiBold"
        $memoryText.Foreground = [Media.Brushes]::White
        $memoryText.Margin = [Thickness]::new(0, 0, 0, 5)
        $contentStack.Children.Add($memoryText) | Out-Null
        
        # Threshold info
        $thresholdText = [TextBlock]::new()
        $thresholdText.Text = "Threshold exceeded by $($($MemoryUsagePct - 90).ToString('F1'))%"
        $thresholdText.FontSize = 14
        $thresholdText.Foreground = [Media.Brushes]::LightGray
        $thresholdText.Margin = [Thickness]::new(0, 0, 0, 15)
        $contentStack.Children.Add($thresholdText) | Out-Null
        
        # Top processes
        if ($TopProcesses.Count -gt 0) {
            $processTitle = [TextBlock]::new()
            $processTitle.Text = "Top Memory Consumers:"
            $processTitle.FontSize = 14
            $processTitle.FontWeight = "SemiBold"
            $processTitle.Foreground = [Media.Brushes]::LightBlue
            $processTitle.Margin = [Thickness]::new(0, 0, 0, 5)
            $contentStack.Children.Add($processTitle) | Out-Null
            
            $processesToShow = [Math]::Min($TopProcesses.Count, 5)
            for ($i = 0; $i -lt $processesToShow; $i++) {
                $procText = [TextBlock]::new()
                $procText.Text = "$($i + 1). $($TopProcesses[$i])"
                $procText.FontSize = 12
                $procText.Foreground = [Media.Brushes]::White
                $procText.Margin = [Thickness]::new(15, 2, 0, 2)
                $contentStack.Children.Add($procText) | Out-Null
            }
        }
        
        [Grid]::SetRow($contentStack, 1)
        $grid.Children.Add($contentStack) | Out-Null
        
        # Actions - Buttons
        $buttonStack = [StackPanel]::new()
        $buttonStack.Orientation = "Horizontal"
        $buttonStack.HorizontalAlignment = "Center"
        $buttonStack.Margin = [Thickness]::new(0, 10, 0, 0)
        
        # Cleanup button
        $cleanupButton = [Button]::new()
        $cleanupButton.Content = "CLEAN NOW"
        $cleanupButton.FontSize = 14
        $cleanupButton.FontWeight = "Bold"
        $cleanupButton.Padding = [Thickness]::new(20, 10, 20, 10)
        $cleanupButton.Margin = [Thickness]::new(0, 0, 10, 0)
        $cleanupButton.Background = [Media.Brushes]::Orange
        $cleanupButton.Foreground = [Media.Brushes]::White
        $cleanupButton.BorderBrush = [Media.Brushes]::Transparent
        $cleanupButton.Cursor = "Hand"
        $cleanupButton.Tag = "cleanup"
        
        # Cleanup button click event
        $cleanupButton.add_Click({
            $script:CurrentPopupWindow.DialogResult = $true
            $script:CurrentPopupWindow.Close()
            
            if ($CleanupAction) {
                Write-Log "INFO" "Executing cleanup action from popup"
                & $CleanupAction
            }
        })
        
        # Hover effect
        $cleanupButton.add_MouseEnter({
            $this.Background = [Media.Brushes]::DarkOrange
        })
        $cleanupButton.add_MouseLeave({
            $this.Background = [Media.Brushes]::Orange
        })
        
        $buttonStack.Children.Add($cleanupButton) | Out-Null
        
        # Dismiss button
        $dismissButton = [Button]::new()
        $dismissButton.Content = "DISMISS"
        $dismissButton.FontSize = 14
        $dismissButton.Padding = [Thickness]::new(20, 10, 20, 10)
        $dismissButton.Margin = [Thickness]::new(0, 0, 0, 0)
        $dismissButton.Background = [Media.Brushes]::Gray
        $dismissButton.Foreground = [Media.Brushes]::White
        $dismissButton.BorderBrush = [Media.Brushes]::Transparent
        $dismissButton.Cursor = "Hand"
        
        $dismissButton.add_Click({
            $script:CurrentPopupWindow.DialogResult = $false
            $script:CurrentPopupWindow.Close()
        })
        
        # Hover effect
        $dismissButton.add_MouseEnter({
            $this.Background = [Media.Brushes]::DarkGray
        })
        $dismissButton.add_MouseLeave({
            $this.Background = [Media.Brushes]::Gray
        })
        
        $buttonStack.Children.Add($dismissButton) | Out-Null
        
        [Grid]::SetRow($buttonStack, 2)
        $grid.Children.Add($buttonStack) | Out-Null
        
        # Add grid to border
        $border.Child = $grid
        
        # Add border to window
        $script:CurrentPopupWindow.Content = $border
        
        # Show window
        Write-Log "INFO" "Showing alert popup: $($MemoryUsagePct.ToString('F1'))%"
        $result = $script:CurrentPopupWindow.ShowDialog()
        
        # Reset reference
        $script:CurrentPopupWindow = $null
        
    } catch {
        Write-Log "ERROR" "Failed to show alert popup: $_"
        $script:CurrentPopupWindow = $null
    }
}

<#
.SYNOPSIS
    Set alert cooldown period
.DESCRIPTION
    Configure the minimum time between consecutive alerts
#>
function Set-AlertCooldown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Seconds
    )
    
    if ($Seconds -lt 0) {
        throw "Cooldown seconds must be >= 0"
    }
    
    $script:AlertCooldownSeconds = $Seconds
    Write-Log "INFO" "Alert cooldown set to $Seconds seconds"
}

<#
.SYNOPSIS
    Reset alert timer
.DESCRIPTION
    Reset the last alert time, allowing immediate next alert
#>
function Reset-AlertTimer {
    [CmdletBinding()]
    param()
    
    $script:LastAlertTime = $null
    Write-Log "INFO" "Alert timer reset"
}

# Export functions
Export-ModuleMember -Function @(
    'Show-AlertPopup',
    'Set-AlertCooldown',
    'Reset-AlertTimer'
)
