<?php

declare(strict_types=1);

namespace App\Tasks;

use DateTimeImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class MaterializeRuns
{
    public const WINDOW_DAYS = 7;

    /**
     * Materialize task occurrences for a farm starting at $start (inclusive).
     *
     * Rules:
     *  - once: a single occurrence on start_on.
     *  - daily: one occurrence per day inside the seven-day window.
     *  - weekly: one occurrence per week aligned to the start_on weekday.
     *
     * A run is unique per (template_id, business_date); repeated calls are safe.
     *
     * @return int number of newly created runs
     */
    public function handle(string $farmId, DateTimeImmutable $start): int
    {
        $templates = DB::table('task_templates')
            ->where('farm_id', $farmId)
            ->where('active', true)
            ->get();

        $created = 0;

        foreach ($templates as $template) {
            $startOn = new DateTimeImmutable((string) $template->start_on);
            $endOn = $template->end_on ? new DateTimeImmutable((string) $template->end_on) : null;

            foreach ($this->occurrenceDates($template, $startOn, $endOn, $start) as $date) {
                $exists = DB::table('task_runs')
                    ->where('template_id', $template->id)
                    ->where('business_date', $date)
                    ->exists();

                if ($exists) {
                    continue;
                }

                $checklist = TaskService::checklistFromSop((string) $template->sop);

                $snapshot = [
                    'title' => $template->title,
                    'sop' => $template->sop,
                    'checklist_items' => $checklist,
                    'scheduled_at' => $date.'T'.$template->local_time,
                    'latest_note' => null,
                ];

                DB::table('task_runs')->insert([
                    'id' => (string) Str::uuid(),
                    'farm_id' => $farmId,
                    'template_id' => $template->id,
                    'cage_id' => $template->cage_id,
                    'business_date' => $date,
                    'assignee_id' => $template->assignee_id,
                    'snapshot' => json_encode($snapshot),
                    'status' => 'open',
                    'version' => 1,
                    'updated_at' => now(),
                ]);

                $created++;
            }
        }

        return $created;
    }

    /**
     * @return array<int, string> list of business dates (Y-m-d)
     */
    private function occurrenceDates(object $template, DateTimeImmutable $startOn, ?DateTimeImmutable $endOn, DateTimeImmutable $start): array
    {
        $recurrence = (string) $template->recurrence;
        $dates = [];

        if ($recurrence === 'once') {
            return $startOn >= $start ? [$startOn->format('Y-m-d')] : [];
        }

        if ($recurrence === 'daily') {
            for ($i = 0; $i < self::WINDOW_DAYS; $i++) {
                $date = $start->modify("+{$i} days");
                if ($date < $startOn) {
                    continue;
                }
                if ($endOn && $date > $endOn) {
                    break;
                }
                $dates[] = $date->format('Y-m-d');
            }

            return $dates;
        }

        // weekly: same weekday as start_on, within the window
        if ($recurrence === 'weekly') {
            $weekday = (int) $startOn->format('N');
            for ($i = 0; $i < self::WINDOW_DAYS; $i++) {
                $date = $start->modify("+{$i} days");
                if ($date < $startOn) {
                    continue;
                }
                if ($endOn && $date > $endOn) {
                    break;
                }
                if ((int) $date->format('N') === $weekday) {
                    $dates[] = $date->format('Y-m-d');
                }
            }
        }

        return $dates;
    }
}
