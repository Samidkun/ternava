<?php

declare(strict_types=1);

namespace App\Contracts\Dto;

final readonly class Attachment
{
    /**
     * @param  array<string, mixed>  $raw
     */
    public function __construct(
        public array $raw = []
    ) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public static function fromArray(array $data): self
    {
        return new self($data);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return $this->raw;
    }
}
