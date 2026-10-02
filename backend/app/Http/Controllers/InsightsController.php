<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Insights\CsvWriter;
use App\Insights\ReportService;
use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

class InsightsController extends Controller
{
    public function __construct(
        protected ReportService $reportService,
        protected CsvWriter $csvWriter
    ) {}

    protected function getActor(Request $request): ActorScope
    {
        $user = $request->user();
        if (! $user) {
            throw new AccessDeniedHttpException('Tidak terautentikasi.');
        }

        $membership = DB::table('memberships')
            ->where('user_id', $user->id)
            ->where('active', true)
            ->first();

        if (! $membership) {
            throw new AccessDeniedHttpException('Pengguna tidak memiliki keanggotaan aktif.');
        }

        return new ActorScope(
            actorId: (string) $user->id,
            farmId: (string) $membership->farm_id,
            role: (string) $membership->role
        );
    }

    public function dashboard(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);

        $validated = $request->validate([
            'business_date' => ['required', 'date'],
        ]);

        return response()->json([
            'data' => $this->reportService->dashboard($actor, (string) $validated['business_date']),
        ]);
    }

    public function operations(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);

        $validated = $request->validate([
            'from' => ['required', 'date'],
            'to' => ['required', 'date'],
            'cage_id' => ['nullable', 'string', 'uuid'],
        ]);

        $report = $this->reportService->operations(
            $actor,
            (string) $validated['from'],
            (string) $validated['to']
        );

        if (! empty($validated['cage_id'])) {
            $report['rows'] = array_values(array_filter(
                $report['rows'],
                fn ($row) => $row['cage_id'] === $validated['cage_id']
            ));
        }

        return response()->json(['data' => $report]);
    }

    public function export(Request $request): StreamedResponse
    {
        $actor = $this->getActor($request);

        $validated = $request->validate([
            'from' => ['required', 'date'],
            'to' => ['required', 'date'],
        ]);

        $report = $this->reportService->operations(
            $actor,
            (string) $validated['from'],
            (string) $validated['to']
        );

        $csv = $this->csvWriter;

        return new StreamedResponse(function () use ($csv, $report): void {
            $stream = fopen('php://output', 'w');
            $csv->write($report, $stream);
            fclose($stream);
        }, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="laporan-operasional.csv"',
        ]);
    }
}
