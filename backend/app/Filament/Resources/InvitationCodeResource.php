<?php

namespace App\Filament\Resources;

use App\Filament\Resources\InvitationCodeResource\Pages;
use App\Filament\Resources\InvitationCodeResource\RelationManagers;
use App\Models\InvitationCode;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\SoftDeletingScope;

class InvitationCodeResource extends Resource
{
    protected static ?string $model = InvitationCode::class;

    protected static ?string $navigationIcon = 'heroicon-o-rectangle-stack';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                //
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                //
            ])
            ->filters([
                //
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListInvitationCodes::route('/'),
            'create' => Pages\CreateInvitationCode::route('/create'),
            'edit' => Pages\EditInvitationCode::route('/{record}/edit'),
        ];
    }
}
