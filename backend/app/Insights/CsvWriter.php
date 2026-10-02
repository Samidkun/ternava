<?php

declare(strict_types=1);

namespace App\Insights;

/**
 * Writes a report as RFC 4180 CSV with a UTF-8 BOM. Cells that begin with a
 * spreadsheet formula character are neutralized to prevent CSV injection.
 */
class CsvWriter
{
    /**
     * @param  array<string, mixed>  $report
     * @param  resource  $stream
     */
    public function write(array $report, $stream): void
    {
        // UTF-8 BOM so Excel reads the file as UTF-8.
        fwrite($stream, "\xEF\xBB\xBF");

        // A header comment line carries period/timezone/as_of context.
        fputcsv($stream, array_map([$this, 'cell'], [
            'Laporan Operasional',
            'from:'.($report['from'] ?? ''),
            'to:'.($report['to'] ?? ''),
            'timezone:'.($report['timezone'] ?? ''),
            'as_of:'.($report['as_of'] ?? ''),
        ]), ',', '"', '');

        fputcsv($stream, array_map([$this, 'cell'], [
            'business_date',
            'cage_id',
            'flock_id',
            'record_state',
            'eggs_count',
            'feed_kg',
            'mortality_count',
            'condition',
        ]), ',', '"', '');

        foreach (($report['rows'] ?? []) as $row) {
            fputcsv($stream, array_map([$this, 'cell'], [
                (string) ($row['business_date'] ?? ''),
                (string) ($row['cage_id'] ?? ''),
                (string) ($row['flock_id'] ?? ''),
                (string) ($row['record_state'] ?? ''),
                $row['eggs_count'] === null ? '' : (string) $row['eggs_count'],
                $row['feed_kg'] === null ? '' : (string) $row['feed_kg'],
                $row['mortality_count'] === null ? '' : (string) $row['mortality_count'],
                (string) ($row['condition'] ?? ''),
            ]), ',', '"', '');
        }
    }

    /**
     * Neutralize formula injection by prefixing a quote when a cell would be
     * interpreted as a formula by a spreadsheet application.
     */
    public function cell(string $value): string
    {
        if (preg_match('/^[\s]*[=+@-]/u', $value) === 1) {
            return "'".$value;
        }

        return $value;
    }
}
