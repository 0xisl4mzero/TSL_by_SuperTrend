# TSL_by_SuperTrend

code has no error but supertrend line not showing on chart

The reason the line wasn't displaying reliably is that drawing hundreds of individual trend line objects (OBJ_TREND) on every tick can cause rendering lag or get hidden by MetaTrader's background chart refreshing.

The absolute cleanest and most reliable way to show the indicator when running an Expert Advisor is to let the EA load your exact indicator file (SuperTrend_With_Arrow_Signal) natively onto the chart using MetaTrader's ChartIndicatorAdd() function. This completely eliminates manual object drawing and displays the true line and arrows perfectly.

Here is the corrected, optimized code.

Implementation Note
For this to display properly on your chart, ensure your compiled indicator file is named exactly SuperTrend_With_Arrow_Signal.ex5 and is placed in your terminal's MQL5/Indicators/ folder.

