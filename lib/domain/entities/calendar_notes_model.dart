import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';

part 'calendar_notes_model.g.dart';

@JsonSerializable()
class CalendarNotesModel extends Equatable {
  final DateTime? date;
  final Map<String, List<String>> notes;

  CalendarNotesModel({
    this.date,
    this.notes = const {},
  });

  factory CalendarNotesModel.fromJson(Map<String, dynamic> json) =>
      _$CalendarNotesModelFromJson(json);

  Map<String, dynamic> toJson() => _$CalendarNotesModelToJson(this);

  List<String> getNotesForDate(DateTime date) {
    final key = (date.millisecondsSinceEpoch ~/ (24 * 60 * 60 * 1000)).toString();
    return notes[key] ?? [];
  }

  CalendarNotesModel addNoteForDate(DateTime date, String note) {
    final key = (date.millisecondsSinceEpoch ~/ (24 * 60 * 60 * 1000)).toString();
    final updatedNotes = Map<String, List<String>>.from(notes);
    
    if (updatedNotes.containsKey(key)) {
      updatedNotes[key] = [...updatedNotes[key]!, note];
    } else {
      updatedNotes[key] = [note];
    }
    
    return CalendarNotesModel(
      date: this.date,
      notes: updatedNotes,
    );
  }

  @override
  List<Object?> get props => [date, notes];
}